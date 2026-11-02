"""Builds every example graphic: python3 build.py [style_prefix ...] [--only name,...]"""
import json, os, subprocess, sys
from styles import STYLES, ORDER
import svgcore
from svgcore import Painter, svg_doc
import subjects
import compositions

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT_HTML = os.path.join(HERE, "out_html")
FONT_DIR = os.path.join(HERE, "fonts")


def font_css():
    css = []
    for f in sorted(os.listdir(FONT_DIR)):
        if not f.endswith(".woff2"):
            continue
        base = f[:-6]
        parts = base.split("-latin-")
        fam = " ".join(w if w in ("SC", "EB", "IM") else w.capitalize() for w in parts[0].split("-"))
        fam = fam.replace("Im Fell English Sc", "IM Fell English SC").replace("Eb Garamond", "EB Garamond")
        fam = fam.replace("Amatic Sc", "Amatic SC")
        wt, sty = parts[1].split("-")
        css.append(f"@font-face{{font-family:'{fam}';src:url('file://{FONT_DIR}/{f}') format('woff2');"
                   f"font-weight:{wt};font-style:{sty};}}")
    return "\n".join(css)


FONT_CSS = None


def page(body, w, h, extra_css=""):
    global FONT_CSS
    if FONT_CSS is None:
        FONT_CSS = font_css()
    return (f"<!doctype html><html><head><meta charset='utf-8'><style>{FONT_CSS}\n"
            f"html,body{{margin:0;padding:0;background:transparent;width:{w}px;height:{h}px;overflow:hidden}}"
            f"{extra_css}</style></head><body>{body}</body></html>")


def sprite(st, fn, size=512, name=None):
    P = Painter(st)
    filt = P.sprite_filter()
    body = subjects.guides(P, name) + fn(P)
    return svg_doc(size, size, f"<g {filt}>{body}</g>", P)


SPRITES = {
    "blacksmith": subjects.blacksmith,
    "adventurer": subjects.adventurer,
    "sword": subjects.sword,
    "armor": subjects.armor,
    "tree": subjects.tree,
}


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    only = None
    for a in sys.argv[1:]:
        if a.startswith("--only="):
            only = a.split("=", 1)[1].split(",")
    os.makedirs(OUT_HTML, exist_ok=True)
    jobs = []
    for sk in ORDER:
        if args and not any(sk.startswith(a) for a in args):
            continue
        st = STYLES[sk]
        outdir = os.path.join(ROOT, sk)
        os.makedirs(outdir, exist_ok=True)
        items = []
        if "paper" in st:
            items.append(("paper_grid", lambda st=st: page(*compositions.paper(st, True)), 512, 512, False))
            items.append(("paper_plain", lambda st=st: page(*compositions.paper(st, False)), 512, 512, False))
        for name, fn in SPRITES.items():
            items.append((name, lambda st=st, fn=fn, name=name: page(sprite(st, fn, name=name), 512, 512), 512, 512, True))
        items.append(("town_view", lambda st=st: page(compositions.town(st, page), 1920, 1080), 1920, 1080, False))
        items.append(("menu_screen", lambda st=st: page(*compositions.menu(st)), 1920, 1080, False))
        items.append(("font_reference", lambda st=st: page(*compositions.fonts(st)), 1920, 1080, False))
        if "paper" in st:
            items.append(("scene_composite", lambda st=st: page(*compositions.scene_composite(st)), 1920, 1080, False))
            items.append(("paper_comparison", lambda st=st: page(*compositions.paper_comparison(st)), 1920, 1080, False))
        for name, mk, w, h, tr in items:
            if only and name not in only:
                continue
            html = os.path.join(OUT_HTML, f"{sk}_{name}.html")
            with open(html, "w") as f:
                f.write(mk())
            jobs.append(dict(html=html, png=os.path.join(outdir, name + ".png"), w=w, h=h, transparent=tr))
    jf = os.path.join(OUT_HTML, "jobs.json")
    with open(jf, "w") as f:
        json.dump(jobs, f)
    subprocess.run(["node", os.path.join(HERE, "render.js"), jf], check=True)


if __name__ == "__main__":
    main()
