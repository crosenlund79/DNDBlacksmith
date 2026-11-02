"""Side-by-side sheet: 08 (85:15) vs ink_parchment_gothic_80_20, same assets and framing."""
import os
from PIL import Image, ImageDraw, ImageFont
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
A, B = "08_ink_parchment_gothic", "ink_parchment_gothic_80_20"
OUT = os.path.join(ROOT, B, "comparison_85_15_vs_80_20.png")
FB = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 30)
FS = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 20)
CW, GAP, HEAD = 960, 24, 90
sprites = ["blacksmith", "adventurer", "sword", "armor", "tree"]
comps = ["town_view", "menu_screen", "font_reference"]
SP = CW // 5
H = HEAD + (SP + 40) + len(comps) * (540 + 40) + 20
W = Image.new("RGB", (CW * 2 + GAP, H), (40, 30, 22))
d = ImageDraw.Draw(W)
for col, (folder, label, sub) in enumerate([(A, "85 : 15 — The Smith's Chronicle", "08_ink_parchment_gothic (previous hybrid)"),
                                             (B, "80 : 20 — Ember & Ash", "ink_parchment_gothic_80_20 (this variant)")]):
    x0 = col * (CW + GAP)
    d.text((x0 + 16, 14), label, fill=(240, 226, 196), font=FB)
    d.text((x0 + 16, 54), sub, fill=(200, 180, 150), font=FS)
    y = HEAD
    for i, n in enumerate(sprites):
        im = Image.open(f"{ROOT}/{folder}/{n}.png").convert("RGBA").resize((SP, SP), Image.LANCZOS)
        bg = Image.new("RGBA", (SP, SP), (226, 206, 162, 255))
        bg.alpha_composite(im)
        W.paste(bg.convert("RGB"), (x0 + i * SP, y))
    y += SP + 40
    for n in comps:
        d.text((x0 + 16, y - 32), n, fill=(200, 180, 150), font=FS)
        W.paste(Image.open(f"{ROOT}/{folder}/{n}.png").convert("RGB").resize((CW, 540), Image.LANCZOS), (x0, y))
        y += 540 + 40
W.save(OUT)
print(OUT)
