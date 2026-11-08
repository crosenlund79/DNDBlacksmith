"""Art for the property & workshop system: the brass recipe plaque that marks each room's main station.
Run: python3 make_property_art.py   (writes assets/sprites/ui/template_recipe_plaque.png)"""
import os
from PIL import Image, ImageDraw
import artlib

S = 4  # supersample


def plaque():
    W = 44 * S
    im = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = W // 2
    # brass roundel with an inked rim
    d.ellipse([2 * S, 2 * S, W - 2 * S, W - 2 * S], fill=(32, 20, 12, 255))
    d.ellipse([4 * S, 4 * S, W - 4 * S, W - 4 * S], fill=(184, 146, 62, 255))
    d.ellipse([7 * S, 7 * S, W - 7 * S, W - 7 * S], fill=(214, 178, 96, 255))
    # an open recipe book
    bw, bh = 24 * S, 15 * S
    x0, y0 = c - bw // 2, c - bh // 2 + 1 * S
    d.polygon([(x0, y0 + 2 * S), (c, y0 + 4 * S), (c, y0 + bh), (x0, y0 + bh - 2 * S)], fill=(239, 228, 204, 255), outline=(32, 20, 12, 255))
    d.polygon([(c, y0 + 4 * S), (x0 + bw, y0 + 2 * S), (x0 + bw, y0 + bh - 2 * S), (c, y0 + bh)], fill=(232, 218, 190, 255), outline=(32, 20, 12, 255))
    d.line([(c, y0 + 4 * S), (c, y0 + bh)], fill=(32, 20, 12, 255), width=S)
    for k in range(3):
        yy = y0 + 6 * S + k * 3 * S
        d.line([(x0 + 3 * S, yy - S), (c - 2 * S, yy)], fill=(94, 66, 28, 255), width=S // 2 + 1)
        d.line([(c + 2 * S, yy), (x0 + bw - 3 * S, yy - S)], fill=(94, 66, 28, 255), width=S // 2 + 1)
    # rubric ribbon
    d.polygon([(c + 4 * S, y0 + 3 * S), (c + 7 * S, y0 + 3 * S), (c + 7 * S, y0 + bh + 4 * S), (c + 5 * S + S // 2, y0 + bh + 2 * S), (c + 4 * S, y0 + bh + 4 * S)], fill=(126, 36, 24, 255))
    im = im.resize((44, 44), Image.LANCZOS)
    out = artlib.tpath(os.path.join(artlib.SPR, "ui", "recipe_plaque.png"))
    im.save(out)
    print("wrote", out)


if __name__ == "__main__":
    plaque()
