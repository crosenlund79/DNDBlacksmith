"""Builds side-by-side comparison sheets in ../comparison/ (one per asset type)."""
import os
from PIL import Image, ImageDraw, ImageFont
from styles import STYLES, ORDER
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "comparison")
os.makedirs(OUT, exist_ok=True)
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
F = ImageFont.truetype(FONT, 20)
F2 = ImageFont.truetype(FONT.replace("-Bold", ""), 16)
SPRITES = ["blacksmith", "adventurer", "sword", "armor", "tree"]
COMPS = ["town_view", "menu_screen", "font_reference"]


def label(d, x, y, sk):
    st = STYLES[sk]
    tag = sk[:2] if sk[0].isdigit() else "80:20"
    d.text((x, y), f"{tag}  {st['name']}"[:34], fill=(30, 26, 22), font=F)
    d.text((x, y + 26), st["title"], fill=(100, 90, 80), font=F2)


for n in SPRITES:
    cell = 384
    W = Image.new("RGB", (cell * len(ORDER), cell + 70), (236, 232, 224))
    d = ImageDraw.Draw(W)
    for i, sk in enumerate(ORDER):
        im = Image.open(f"{ROOT}/{sk}/{n}.png").convert("RGBA").resize((cell, cell), Image.LANCZOS)
        bg = Image.new("RGBA", (cell, cell), (150, 168, 140, 255) if n != "tree" else (200, 196, 186, 255))
        # checker to show transparency
        cd = ImageDraw.Draw(bg)
        for yy in range(0, cell, 32):
            for xx in range(0, cell, 32):
                if (xx // 32 + yy // 32) % 2:
                    cd.rectangle([xx, yy, xx + 31, yy + 31], fill=(140, 158, 130, 255) if n != "tree" else (190, 186, 176, 255))
        bg.alpha_composite(im)
        W.paste(bg.convert("RGB"), (i * cell, 70))
        label(d, i * cell + 12, 10, sk)
    W.save(f"{OUT}/{n}_comparison.png")

for n in COMPS:
    w, h = 960, 540
    W = Image.new("RGB", (w * 2 + 20, (h + 70) * ((len(ORDER) + 1) // 2)), (236, 232, 224))
    d = ImageDraw.Draw(W)
    for i, sk in enumerate(ORDER):
        x, y = (i % 2) * (w + 20), (i // 2) * (h + 70)
        im = Image.open(f"{ROOT}/{sk}/{n}.png").convert("RGB").resize((w, h), Image.LANCZOS)
        W.paste(im, (x, y + 64))
        label(d, x + 8, y + 8, sk)
    W.save(f"{OUT}/{n}_comparison.png")
print("ok")
