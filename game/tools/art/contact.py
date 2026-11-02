"""Contact sheets for review: python3 contact.py [stations|props|icons|textures|roofs|ui ...]"""
import os
import sys
from PIL import Image, ImageDraw, ImageFont
from artlib import SPR, OUT


def font(sz):
    for p in ["/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"]:
        if os.path.exists(p):
            return ImageFont.truetype(p, sz)
    return ImageFont.load_default()


def sheet(name, files, zoom=1.0, cols=None, bg=(220, 199, 154), max_w=2400, tile=None, dark=False):
    ims = []
    for f in files:
        im = Image.open(f).convert("RGBA")
        if tile:
            t = Image.new("RGBA", (im.width * tile, im.height * tile))
            for a in range(tile):
                for b in range(tile):
                    t.paste(im, (a * im.width, b * im.height))
            im = t
        if zoom != 1:
            im = im.resize((int(im.width * zoom), int(im.height * zoom)), Image.NEAREST if zoom >= 2 else Image.LANCZOS)
        ims.append((os.path.basename(f)[:-4], im))
    pad, lab = 14, 16
    fnt = font(12)
    rows, cur, x, rh = [], [], pad, 0
    for n, im in ims:
        w = max(im.width, 70)
        if x + w + pad > max_w and cur:
            rows.append((cur, rh))
            cur, x, rh = [], pad, 0
        cur.append((n, im, x))
        x += w + pad
        rh = max(rh, im.height)
    rows.append((cur, rh))
    H = pad + sum(rh + lab + pad for _, rh in rows)
    W = max_w
    out = Image.new("RGBA", (W, H), bg + (255,))
    d = ImageDraw.Draw(out)
    # checker strip behind each image so transparency is visible
    y = pad
    for cur, rh in rows:
        for n, im, x in cur:
            if dark:
                d.rectangle([x - 2, y - 2, x + im.width + 1, y + im.height + 1], fill=(48, 36, 26))
            else:
                d.rectangle([x - 2, y - 2, x + im.width + 1, y + im.height + 1], outline=(150, 130, 100))
            out.alpha_composite(im, (x, y))
            d.text((x, y + im.height + 2), n, fill=(32, 20, 12), font=fnt)
        y += rh + lab + pad
    os.makedirs(OUT, exist_ok=True)
    p = os.path.join(OUT, f"sheet_{name}.png")
    out.convert("RGB").save(p)
    print(p, out.size)


def files(sub, pref=""):
    d = os.path.join(SPR, sub)
    return sorted(os.path.join(d, f) for f in os.listdir(d) if f.endswith(".png") and f.startswith(pref))


if __name__ == "__main__":
    which = sys.argv[1:] or ["stations", "props", "icons", "textures", "roofs", "ui"]
    if "stations" in which:
        sheet("stations", files("stations"), zoom=1.5, max_w=1900)
        sheet("stations_1x", files("stations"), zoom=1.0, max_w=1400)
        sheet("stations_floor", files("stations"), zoom=1.0, max_w=1400, bg=(150, 132, 108))
    if "props" in which:
        sheet("props", files("props"), zoom=1.0, max_w=1900)
    if "icons" in which:
        sheet("icons", files("icons"), zoom=1.0, max_w=1100)
        sheet("icons_dark", files("icons"), zoom=1.0, max_w=1100, bg=(40, 30, 22), dark=True)
    if "textures" in which:
        sheet("textures", files("textures"), zoom=0.5, max_w=1800, tile=2)
    if "roofs" in which:
        sheet("roofs", files("roofs"), zoom=0.35, max_w=1800, bg=(205, 190, 150))
    if "ui" in which:
        sheet("ui", [f for f in files("ui") if "menu_background" not in f and "vignette" not in f], zoom=1.0, max_w=1600, bg=(120, 100, 80))
