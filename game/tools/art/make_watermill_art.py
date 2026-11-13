#!/usr/bin/env python3
"""v1.7 (#65–66): the watermill by the millstream — two template sprites in the village's ink-and-paper style (PIL only,
deterministic). Writes TEMPLATE art only (assets/sprites/props/template_*.png); a creator's own props/watermill.png or
props/mill_wheel.png replaces them without code changes and is never touched here.
    props/watermill    the mill house seen from above: a hipped thatch roof, timber gable, a millrace chute (192×176)
    props/mill_wheel   the undershot wheel seen side-on: rim, spokes and paddles (rotated by the world) (120×120)
python3 tools/art/make_watermill_art.py"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "assets", "sprites", "props")
INK = (32, 20, 12, 255)
THATCH = (176, 142, 78, 255)
THATCH_D = (138, 104, 52, 255)
WOOD = (122, 84, 48, 255)
WOOD_D = (86, 56, 30, 255)
STONE = (150, 142, 128, 255)
SS = 3   # supersampling


def wob(rng, pts, a=1.2):
    return [(x + rng.uniform(-a, a) * SS, y + rng.uniform(-a, a) * SS) for x, y in pts]


def mill_house():
    w, h = 192, 176
    rng = random.Random(65)
    im = Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    s = SS
    # soft ground shadow
    sh = Image.new("RGBA", im.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle((18 * s, 30 * s, 182 * s, 170 * s), 14 * s, fill=(20, 12, 6, 90))
    im.alpha_composite(sh.filter(ImageFilter.GaussianBlur(6 * s)))
    # stone footing and the millrace chute on the west side
    d.rounded_rectangle((14 * s, 24 * s, 176 * s, 160 * s), 10 * s, fill=STONE, outline=INK, width=3 * s)
    for i in range(26):
        x, y = rng.uniform(18, 172) * s, rng.uniform(28, 156) * s
        d.ellipse((x - 5 * s, y - 3 * s, x + 5 * s, y + 3 * s), outline=(110, 102, 90, 180), width=s)
    d.rectangle((0, 70 * s, 22 * s, 96 * s), fill=WOOD, outline=INK, width=2 * s)
    for k in range(4):
        d.line((0, (74 + k * 6) * s, 22 * s, (74 + k * 6) * s), fill=WOOD_D, width=s)
    # hipped thatch roof
    roof = wob(rng, [(24 * s, 18 * s), (168 * s, 18 * s), (184 * s, 92 * s), (168 * s, 166 * s), (24 * s, 166 * s), (8 * s, 92 * s)])
    d.polygon(roof, fill=THATCH, outline=INK)
    ridge = [(52 * s, 92 * s), (140 * s, 92 * s)]
    for x0, y0 in roof:
        d.line((x0, y0, ridge[0][0] if x0 < 96 * s else ridge[1][0], ridge[0][1]), fill=THATCH_D, width=2 * s)
    d.line(ridge[0] + ridge[1], fill=INK, width=3 * s)
    for i in range(140):   # straw strokes
        x, y = rng.uniform(22, 170) * s, rng.uniform(22, 162) * s
        a = math.atan2(92 * s - y, 96 * s - x)
        L = rng.uniform(6, 12) * s
        d.line((x, y, x + math.cos(a) * L, y + math.sin(a) * L), fill=THATCH_D, width=s)
    d.polygon(roof, outline=INK, width=4 * s)
    # chimney and a dormer
    d.rectangle((120 * s, 40 * s, 136 * s, 58 * s), fill=STONE, outline=INK, width=3 * s)
    d.rectangle((124 * s, 44 * s, 132 * s, 54 * s), fill=(40, 30, 24, 255))
    d.polygon([(70 * s, 120 * s), (92 * s, 120 * s), (81 * s, 104 * s)], fill=WOOD, outline=INK)
    im = im.resize((w, h), Image.LANCZOS)
    im.save(os.path.join(OUT, "template_watermill.png"))


def mill_wheel():
    sz = 120
    s = SS
    im = Image.new("RGBA", (sz * s, sz * s), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = sz * s / 2
    R = 52 * s
    for k in range(12):   # paddles
        a = k * math.tau / 12
        x0, y0 = c + math.cos(a) * (R - 6 * s), c + math.sin(a) * (R - 6 * s)
        x1, y1 = c + math.cos(a) * (R + 6 * s), c + math.sin(a) * (R + 6 * s)
        n = (-math.sin(a) * 5 * s, math.cos(a) * 5 * s)
        d.polygon([(x0 - n[0], y0 - n[1]), (x1 - n[0], y1 - n[1]), (x1 + n[0], y1 + n[1]), (x0 + n[0], y0 + n[1])], fill=WOOD, outline=INK)
    d.ellipse((c - R, c - R, c + R, c + R), outline=INK, width=6 * s)
    d.ellipse((c - R + 4 * s, c - R + 4 * s, c + R - 4 * s, c + R - 4 * s), outline=WOOD, width=3 * s)
    for k in range(6):   # spokes
        a = k * math.tau / 6 + 0.26
        d.line((c, c, c + math.cos(a) * R, c + math.sin(a) * R), fill=WOOD_D, width=5 * s)
        d.line((c, c, c + math.cos(a) * R, c + math.sin(a) * R), fill=INK, width=s)
    d.ellipse((c - 9 * s, c - 9 * s, c + 9 * s, c + 9 * s), fill=WOOD_D, outline=INK, width=3 * s)
    im = im.resize((sz, sz), Image.LANCZOS)
    im.save(os.path.join(OUT, "template_mill_wheel.png"))


if __name__ == "__main__":
    mill_house()
    mill_wheel()
    print("watermill templates written")
