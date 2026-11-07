"""Builds every Ember & Ash world/UI sprite, then the manifest and review contact sheets.
python3 make_world.py            (all)
python3 make_world.py stations props   (subset: stations props icons textures roofs ui interiors)
"interiors" (make_interiors.py) writes extra props/textures/ui files into those same folders."""
import json
import os
import sys
from PIL import Image
import artlib
from artlib import render, SPR

GROUPS = ["stations", "props", "icons", "textures", "roofs", "ui", "interiors"]


def build(groups):
    import make_stations, make_props, make_icons, make_textures, make_roofs, make_ui, make_interiors
    mods = dict(stations=make_stations, props=make_props, icons=make_icons, textures=make_textures, roofs=make_roofs, ui=make_ui,
                interiors=make_interiors)
    for g in groups:
        print("==", g)
        render(mods[g].jobs(), workers=3 if g in ("roofs", "ui") else 4)
        if g == "textures":
            make_textures.tile_test()
        if g == "interiors":
            make_interiors.tile_test(list(make_interiors.TEX_I))
            make_interiors.contact_sheets()


def manifest():
    out = {"generator": "game/tools/art/make_world.py", "style": "ink_parchment_gothic_80_20", "files": {}}
    for g in GROUPS:
        d = os.path.join(SPR, g)
        if not os.path.isdir(d):
            continue
        for f in sorted(os.listdir(d)):
            if f.endswith(".png"):
                w, h = Image.open(os.path.join(d, f)).size
                out["files"][f"{g}/{f}"] = [w, h]
    with open(os.path.join(SPR, "manifest.json"), "w") as fh:
        json.dump(out, fh, indent=1)
    print("manifest:", len(out["files"]), "files")


def verify():
    errs = []
    for s in artlib.load("stations.json"):
        p = os.path.join(SPR, "stations", s["id"] + ".png")
        if not artlib.exists(p) or list(Image.open(p).size) != s["size"]:
            errs.append(p)
    for k, v in artlib.load("props.json").items():
        p = os.path.join(SPR, "props", k + ".png")
        if not artlib.exists(p) or list(Image.open(p).size) != v["size"]:
            errs.append(p)
    for it in artlib.load("items.json"):
        p = os.path.join(SPR, "icons", it["icon"] + ".png")
        if not artlib.exists(p) or Image.open(p).size != (64, 64):
            errs.append(p)
    for b in artlib.load("layout.json")["buildings"]:
        p = os.path.join(SPR, "roofs", b["id"] + ".png")
        if not artlib.exists(p) or Image.open(p).size != (b["rect"][2] * 64, b["rect"][3] * 64):
            errs.append(p)
    print("verify:", "OK" if not errs else errs)


if __name__ == "__main__":
    groups = [a for a in sys.argv[1:] if a in GROUPS] or GROUPS
    build(groups)
    manifest()
    verify()
    import contact
    os.system(f"{sys.executable} {os.path.join(os.path.dirname(__file__), 'contact.py')}")
