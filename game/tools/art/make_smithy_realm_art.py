"""The Living Realm (milestone 2a) — decor for the evolving smithy, straight top-down, Ink & Parchment with a
touch of Gothic Noir:

  props/template_banner_<disc>.png   craft banners hung on a room's north wall (64x80): Smithing, Leatherworking
                                     & Tailoring, Runecrafting, Alchemy, Arcane Metalworking
  props/template_banner_gilt.png     gilt trim and tassels laid over a banner in a Masterwork room
  props/template_lift_platform.png   the aetheric lift: the old hoist's plank platform in a brass ring, ley-stone
Run: python3 make_smithy_realm_art.py   (then: python3 -c "import make_world; make_world.manifest()")"""
import os
import math
import random
from PIL import Image, ImageDraw, ImageFilter
import artlib

S = 4
INK = (32, 20, 12, 255)
PARCH = (233, 220, 188, 255)
PARCH_D = (205, 186, 148, 255)
GILT = (196, 154, 62, 255)
GILT_L = (232, 196, 112, 255)
WOOD = (110, 72, 40, 255)
WOOD_L = (146, 102, 60, 255)

CLOTH = {"classic": (126, 36, 24), "stitching": (138, 92, 46), "runecraft": (52, 66, 98), "alchemy": (58, 88, 46),
         "arcane": (74, 46, 110)}


def _save(im, name, size):
    im = im.resize(size, Image.LANCZOS)
    out = artlib.tpath(os.path.join(artlib.SPR, "props", name + ".png"))
    im.save(out)
    print("wrote", out)
    return out


def _banner_shape(W, H):
    """Swallow-tailed cloth below a rod: polygon points (supersampled)."""
    l, r = 12 * S, W - 12 * S
    top = 10 * S
    bot = H - 6 * S
    notch = H - 20 * S
    return [(l, top), (r, top), (r, bot), ((l + r) // 2, notch), (l, bot)]


def banner(disc):
    W, H = 64 * S, 80 * S
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    # soft shadow on the wall/floor
    sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(sh).polygon([(x + 3 * S, y + 3 * S) for x, y in _banner_shape(W, H)], fill=(20, 12, 6, 110))
    im = Image.alpha_composite(im, sh.filter(ImageFilter.GaussianBlur(3 * S)))
    d = ImageDraw.Draw(im)
    c = CLOTH[disc]
    pts = _banner_shape(W, H)
    d.polygon(pts, fill=c + (255,))
    # cloth folds: a few darker vertical strokes, a lighter edge
    rnd = random.Random(hash(disc) & 0xffff)
    for k in range(5):
        x = 16 * S + k * 8 * S + rnd.randint(-S, S)
        d.line([(x, 12 * S), (x + rnd.randint(-S, S), H - 24 * S)], fill=(max(0, c[0] - 30), max(0, c[1] - 30), max(0, c[2] - 30), 150), width=S)
    d.line([(14 * S, 12 * S), (14 * S, H - 10 * S)], fill=(min(255, c[0] + 40), min(255, c[1] + 40), min(255, c[2] + 40), 160), width=S)
    # a parchment roundel for the emblem
    cx, cy, rr = W // 2, 32 * S, 14 * S
    d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=PARCH, outline=INK, width=S + S // 2)
    _emblem(d, disc, cx, cy, rr)
    # ink outline of the cloth, then the rod with knobs
    d.line(pts + [pts[0]], fill=INK, width=2 * S, joint="curve")
    d.rounded_rectangle([6 * S, 6 * S, W - 6 * S, 12 * S], radius=2 * S, fill=WOOD, outline=INK, width=S + S // 2)
    d.line([(8 * S, 8 * S), (W - 8 * S, 8 * S)], fill=WOOD_L, width=S)
    for x in (5 * S, W - 5 * S):
        d.ellipse([x - 3 * S, 6 * S, x + 3 * S, 12 * S], fill=GILT, outline=INK, width=S)
    return _save(im, "banner_" + disc, (64, 80))


def _emblem(d, disc, cx, cy, r):
    w = S + S // 2
    if disc == "classic":
        # an anvil (horn to the left, face, waist, foot) with a hammer raised over it
        d.polygon([(cx - 12 * S, cy + 1 * S), (cx - 7 * S, cy + 0 * S), (cx + 9 * S, cy + 0 * S), (cx + 9 * S, cy + 3 * S),
                   (cx - 7 * S, cy + 3 * S)], fill=INK)
        d.rectangle([cx - 3 * S, cy + 3 * S, cx + 4 * S, cy + 7 * S], fill=INK)
        d.polygon([(cx - 7 * S, cy + 10 * S), (cx - 4 * S, cy + 7 * S), (cx + 5 * S, cy + 7 * S), (cx + 8 * S, cy + 10 * S)], fill=INK)
        d.line([(cx - 7 * S, cy - 10 * S), (cx + 4 * S, cy - 3 * S)], fill=(110, 72, 40, 255), width=2 * S)
        d.polygon([(cx - 3 * S, cy - 13 * S), (cx + 3 * S, cy - 9 * S), (cx + 0 * S, cy - 5 * S), (cx - 6 * S, cy - 9 * S)], fill=INK)
    elif disc == "stitching":
        d.line([(cx - 8 * S, cy + 8 * S), (cx + 8 * S, cy - 8 * S)], fill=INK, width=w)          # needle
        d.ellipse([cx + 5 * S, cy - 10 * S, cx + 9 * S, cy - 6 * S], outline=INK, width=S)        # its eye
        pts = [(cx + 7 * S + int(6 * S * math.sin(t / 3.0)), cy - 8 * S + t * S) for t in range(0, 17)]
        d.line(pts, fill=(126, 36, 24, 255), width=S)                                              # thread
        d.ellipse([cx - 10 * S, cy - 2 * S, cx - 5 * S, cy + 3 * S], outline=INK, width=S)        # shears' rings
        d.ellipse([cx - 4 * S, cy + 2 * S, cx + 1 * S, cy + 7 * S], outline=INK, width=S)
    elif disc == "runecraft":
        d.rounded_rectangle([cx - 7 * S, cy - 10 * S, cx + 7 * S, cy + 10 * S], radius=3 * S, fill=(150, 146, 136, 255), outline=INK, width=w)
        d.line([(cx, cy - 7 * S), (cx, cy + 7 * S)], fill=INK, width=w)
        d.line([(cx, cy - 7 * S), (cx + 5 * S, cy - 2 * S)], fill=INK, width=w)
        d.line([(cx, cy - 1 * S), (cx - 5 * S, cy + 4 * S)], fill=INK, width=w)
    elif disc == "alchemy":
        d.ellipse([cx - 8 * S, cy - 3 * S, cx + 8 * S, cy + 11 * S], fill=(120, 168, 92, 255), outline=INK, width=w)
        d.rectangle([cx - 3 * S, cy - 11 * S, cx + 3 * S, cy - 2 * S], fill=PARCH, outline=INK, width=S)
        d.rectangle([cx - 4 * S, cy - 13 * S, cx + 4 * S, cy - 10 * S], fill=(110, 72, 40, 255), outline=INK, width=S)
        d.arc([cx - 5 * S, cy, cx + 3 * S, cy + 8 * S], 200, 320, fill=PARCH, width=S)
    elif disc == "arcane":
        pts = []
        for k in range(10):
            a = -math.pi / 2 + k * math.pi / 5
            rad = (11 if k % 2 == 0 else 5) * S
            pts.append((cx + rad * math.cos(a), cy + rad * math.sin(a)))
        d.polygon(pts, fill=(154, 108, 255, 255), outline=INK)
        d.line(pts + [pts[0]], fill=INK, width=S)
        d.ellipse([cx - 2 * S, cy - 2 * S, cx + 2 * S, cy + 2 * S], fill=PARCH)


def gilt():
    W, H = 64 * S, 80 * S
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    pts = _banner_shape(W, H)
    # an inner gilt border following the cloth
    inner = [(pts[0][0] + 3 * S, pts[0][1] + 3 * S), (pts[1][0] - 3 * S, pts[1][1] + 3 * S), (pts[2][0] - 3 * S, pts[2][1] - 5 * S),
             (pts[3][0], pts[3][1] - 4 * S), (pts[4][0] + 3 * S, pts[4][1] - 5 * S)]
    d.line(inner + [inner[0]], fill=GILT, width=2 * S, joint="curve")
    d.line(inner + [inner[0]], fill=GILT_L, width=S // 2 + 1)
    # a gilt ring around the roundel and tassels at the tails
    cx, cy, rr = W // 2, 32 * S, 16 * S
    d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], outline=GILT, width=2 * S)
    for x, y in (pts[2], pts[4]):
        d.line([(x, y - S), (x, y + 4 * S)], fill=INK, width=S)
        d.polygon([(x - 3 * S, y + 4 * S), (x + 3 * S, y + 4 * S), (x + 2 * S, y + 6 * S), (x - 2 * S, y + 6 * S)], fill=GILT, outline=INK)
    # a small star above the rod: a Masterwork room
    sx, sy = W // 2, 4 * S
    star = []
    for k in range(10):
        a = -math.pi / 2 + k * math.pi / 5
        rad = (4 if k % 2 == 0 else 2) * S
        star.append((sx + rad * math.cos(a), sy + 1 * S + rad * math.sin(a)))
    d.polygon(star, fill=GILT_L, outline=INK)
    return _save(im, "banner_gilt", (64, 80))


def lift():
    W = 96 * S
    im = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = W // 2
    R = 44 * S
    # dark shaft rim
    d.ellipse([c - R - 2 * S, c - R - 2 * S, c + R + 2 * S, c + R + 2 * S], fill=(26, 18, 14, 230))
    # plank platform (square, clipped to a circle)
    plat = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    pd = ImageDraw.Draw(plat)
    for k in range(-5, 6):
        y0 = c + k * 8 * S - 4 * S
        tone = WOOD if k % 2 else WOOD_L
        pd.rectangle([c - R, y0, c + R, y0 + 8 * S], fill=tone)
        pd.line([(c - R, y0), (c + R, y0)], fill=INK, width=S)
    mask = Image.new("L", (W, W), 0)
    ImageDraw.Draw(mask).ellipse([c - R + 4 * S, c - R + 4 * S, c + R - 4 * S, c + R - 4 * S], fill=255)
    im.paste(plat, (0, 0), mask)
    d = ImageDraw.Draw(im)
    # brass ring with rivets and four guide posts
    d.ellipse([c - R, c - R, c + R, c + R], outline=INK, width=4 * S)
    d.ellipse([c - R + 2 * S, c - R + 2 * S, c + R - 2 * S, c + R - 2 * S], outline=GILT, width=3 * S)
    for k in range(12):
        a = k * math.pi / 6
        x, y = c + (R - 3 * S) * math.cos(a), c + (R - 3 * S) * math.sin(a)
        d.ellipse([x - S, y - S, x + S, y + S], fill=GILT_L)
    for a in (math.pi / 4, 3 * math.pi / 4, 5 * math.pi / 4, 7 * math.pi / 4):
        x, y = c + R * math.cos(a), c + R * math.sin(a)
        d.rectangle([x - 4 * S, y - 4 * S, x + 4 * S, y + 4 * S], fill=(70, 66, 62, 255), outline=INK, width=S)
    # the ley-stone: a violet glyph ring and a cut stone in the middle
    glow = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse([c - 18 * S, c - 18 * S, c + 18 * S, c + 18 * S], fill=(154, 108, 255, 120))
    im = Image.alpha_composite(im, glow.filter(ImageFilter.GaussianBlur(5 * S)))
    d = ImageDraw.Draw(im)
    d.ellipse([c - 16 * S, c - 16 * S, c + 16 * S, c + 16 * S], outline=(154, 108, 255, 255), width=S + S // 2)
    for k in range(8):
        a = k * math.pi / 4 + 0.2
        x, y = c + 16 * S * math.cos(a), c + 16 * S * math.sin(a)
        d.line([(x - 2 * S * math.sin(a), y + 2 * S * math.cos(a)), (x + 2 * S * math.sin(a), y - 2 * S * math.cos(a))], fill=INK, width=S)
    stone = [(c, c - 8 * S), (c + 6 * S, c - 2 * S), (c + 4 * S, c + 7 * S), (c - 4 * S, c + 7 * S), (c - 6 * S, c - 2 * S)]
    d.polygon(stone, fill=(118, 80, 196, 255), outline=INK)
    d.line([stone[0], (c, c + 7 * S)], fill=(200, 176, 255, 255), width=S)
    return _save(im, "lift_platform", (96, 96))


def contact(paths):
    ims = [Image.open(p).convert("RGBA") for p in paths]
    W = sum(i.width for i in ims) + 20 * (len(ims) + 1)
    H = max(i.height for i in ims) + 40
    sheet = Image.new("RGBA", (W * 3, H * 3), (233, 220, 188, 255))
    x = 20
    for i in ims:
        big = i.resize((i.width * 3, i.height * 3), Image.NEAREST)
        sheet.alpha_composite(big, (x * 3, 20 * 3))
        x += i.width + 20
    # a gilt banner overlaid on the classic banner, to check the trim
    out = os.path.join(os.path.dirname(__file__), "..", "..", "..", "docs", "visual_exploration", "smithy_realm_contact.png")
    return sheet, out


if __name__ == "__main__":
    made = [banner(k) for k in CLOTH]
    made.append(gilt())
    made.append(lift())
    sheet, _ = contact(made)
    comp = Image.open(made[0]).convert("RGBA")
    comp.alpha_composite(Image.open(made[5]).convert("RGBA"))
    big = comp.resize((comp.width * 3, comp.height * 3), Image.NEAREST)
    sheet.alpha_composite(big, (sheet.width - big.width - 30, 30))
    dest = os.environ.get("CONTACT_OUT", "")
    if dest:
        sheet.save(dest)
        print("contact sheet", dest)
