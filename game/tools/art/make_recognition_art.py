"""Recognition art (iteration 010): the smithy's Hall of Fame wall board (props/hall_of_fame_board, 192x96).
Straight top-down: a dark oak board with a carved crest plank (hammer over anvil), three rows of brass
plaques with rivets and engraved lines, one rose-crimson Epic plaque, a small pinned parchment honour
and a laurel sprig. Same painter pipeline as make_props.py.
python3 make_recognition_art.py"""
import os
import random
import artlib  # noqa: F401  (sets sys.path)
from artlib import painter, sprite_svg, lin, fill, render, ell, rect, poly, smooth, ST, INK, RUB, GILT, SPR
from make_props import J, sh_

PAL = ST["pal"]
EPIC = "#b8324f"


def plaque(P, x, y, w, h, epic=False, seed=1):
    rnd = random.Random(seed)
    o = [P.shape(rect(x, y, w, h, 1.6), "gold", s=1.2, lw=1.2, fill_override="#c9a253" if not epic else "#d9b46a")]
    if epic:
        o.append(lin(rect(x + 1.6, y + 1.6, w - 3.2, h - 3.2, 1.2), EPIC, 1.4, 0.95))
    o.append(lin(rect(x + 3, y + 3, w - 6, h - 6, 0.8), "#6e541e", 0.5, 0.7))
    # engraved lines: a title line and two text lines
    o.append(lin(f"M{x+6},{y+h*0.38:.1f} h{w-12:.1f}", "#4a3410", 1.1, 0.85))
    for k in range(2):
        yy = y + h * (0.58 + k * 0.18)
        o.append(lin(f"M{x+7},{yy:.1f} h{w-14-rnd.uniform(0, 8):.1f}", "#6e541e", 0.6, 0.75))
    for (rx, ry) in [(x + 2.6, y + 2.6), (x + w - 2.6, y + 2.6), (x + 2.6, y + h - 2.6), (x + w - 2.6, y + h - 2.6)]:
        o.append(fill(ell(rx, ry, 1.1), "#6e541e") + fill(ell(rx - 0.3, ry - 0.3, 0.6), "#f2dc9a"))
    # a sheen across the brass
    o.append(lin(f"M{x+3},{y+h-3} L{x+w*0.45:.1f},{y+3}", "#fff2c8", 1.2, 0.35))
    if epic:
        cx, cy = x + w - 7, y + h * 0.38
        star = poly([(cx, cy - 3), (cx + 0.9, cy - 0.9), (cx + 3, cy), (cx + 0.9, cy + 0.9), (cx, cy + 3), (cx - 0.9, cy + 0.9), (cx - 3, cy), (cx - 0.9, cy - 0.9)])
        o.append(fill(star, EPIC) + lin(star, INK, 0.4))
    return J(o)


def hall_of_fame_board(P, W, H):
    sh = sh_(P, rect(4, 6, 184, 84, 3), 4, 4)
    b = [P.shape(rect(4, 8, 184, 82, 3), "wood", s=3, fill_override="#4a2f19")]
    b.append(P.shape(rect(10, 22, 172, 62, 1.5), "brown", s=-2, hl=False, lw=1.4, fill_override="#2e1d10"))
    rnd = random.Random(17)
    # oak grain on the field
    b.append(lin(" ".join(f"M12,{y:.1f} C60,{y + rnd.uniform(-2, 2):.1f} 120,{y + rnd.uniform(-2, 2):.1f} 180,{y + rnd.uniform(-1, 1):.1f}" for y in range(26, 82, 5)), "#5a3a1e", 0.6, 0.55))
    # carved crest plank: hammer over anvil, brass trim
    b.append(P.shape(smooth([(52, 8), (96, 2), (140, 8), (146, 15), (140, 23), (96, 27), (52, 23), (46, 15)], t=0.25), "wood", s=1.5, lw=1.6, fill_override="#5e3c20"))
    b.append(lin(smooth([(56, 10), (96, 5), (136, 10), (141, 15), (136, 21), (96, 24), (56, 21), (51, 15)], t=0.25), GILT, 0.9, 0.9))
    anvil = poly([(86, 18), (106, 18), (104, 15), (110, 13), (100, 13), (98, 11), (92, 11), (90, 13), (82, 13), (88, 15)])
    b.append(P.shape(anvil, "darkiron", s=0.6, lw=0.9))
    b.append(P.shape(rect(95, 4.5, 2.2, 8, 0.6), "wood", s=0.3, lw=0.7))
    b.append(P.shape(rect(91, 4, 10, 3.4, 0.8), "darkiron", s=0.4, lw=0.8))
    for x in (60, 132):
        b.append(fill(poly([(x, 12), (x + 3, 15), (x, 18), (x - 3, 15)]), GILT) + lin(poly([(x, 12), (x + 3, 15), (x, 18), (x - 3, 15)]), INK, 0.5))
    # three rows of plaques; one Epic plaque in rose-crimson trim
    rows = [(26, [(16, 34), (54, 34), (92, 34), (130, 30)]), (45, [(16, 30), (50, 40), (94, 34), (132, 30)]), (64, [(16, 36), (56, 30), (90, 36)])]
    k = 0
    for (y, cells) in rows:
        for (x, w) in cells:
            k += 1
            b.append(plaque(P, x, y, w, 15, epic=(k == 6), seed=k))
    # a pinned parchment honour and a laurel sprig in the corner
    g = P.shape(rect(132, 62, 26, 18, 0.5), "paper", s=1, lw=1.0)
    g += P.detail(" ".join(f"M{135},{66 + i*3.2:.1f} h{18 - rnd.uniform(0, 6):.1f}" for i in range(4)), "paper", 0.25, 0.6)
    b.append(f'<g transform="rotate(4 145 71)">{g}</g>')
    b.append(fill(ell(150, 77, 3.0), RUB) + lin(ell(150, 77, 3.0), INK, 0.6) + fill(ell(149, 76, 0.9), "#e8907a", 0.8))
    b.append(fill(ell(145, 63, 1.5), GILT) + lin(ell(145, 63, 1.5), INK, 0.5))
    stem = "M163,80 Q170,66 178,58"
    b.append(lin(stem, PAL["green"][2], 1.4))
    for i in range(6):
        t = i / 5.0
        cx, cy = 163 + 15 * t, 80 - 22 * t
        for sgn in (-1, 1):
            leaf = smooth([(cx, cy), (cx + sgn * 4.0 - 1.5, cy - 2.5), (cx + 1, cy - 4)], t=0.5)
            b.append(P.shape(leaf, "foliage", s=0.4, lw=0.6))
    for x, y in [(8, 12), (184, 12), (8, 86), (184, 86)]:
        b.append(fill(ell(x, y, 1.6), PAL["darkiron"][0]) + lin(ell(x, y, 1.6), INK, 0.5))
    return sh, J(b), ""


def jobs():
    W, H = 192, 96
    P = painter(scale=1.0, lw_mul=0.7)
    sh, body, emit = hall_of_fame_board(P, W, H)
    svg = sprite_svg(P, W, H, sh, body, emit, ss=3, wob=0.9, dil=0.7, grain=0.45, soot=0.6)
    return [dict(name="pr_hall_of_fame_board", svg=svg, w=W, h=H, ss=3, out=os.path.join(SPR, "props", "hall_of_fame_board.png"))]


if __name__ == "__main__":
    render(jobs())
