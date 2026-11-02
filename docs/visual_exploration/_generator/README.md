# Example-graphics generator

These scripts produced every example PNG in `docs/visual_exploration/`. No AI image-generation model was available, so the images are procedural vector illustrations: Python writes SVG/HTML and headless Chromium (Playwright) rasterises it.

| File | Purpose |
|---|---|
| `styles.py` | The seven directions: palettes (light/base/shadow per material role), outline weights, glow colours, rarity colours, fonts |
| `svgcore.py` | Geometry helpers and the `Painter`, which renders each shape in the active style (ink + hatching, painted gradients, cel bands, ink washes, flat two-tone) plus whole-sprite filters (ink wobble, paper grain, silhouette outline) |
| `subjects.py` | Shared subject geometry: blacksmith, adventurer, sword, armour, tree, with per-style proportion tweaks (`PROPS`) |
| `town.py` | The shared village layout and the per-style lighting and map dressing |
| `compositions.py` | Town view, main menu and typography sheet for each direction |
| `build.py` | Builds the HTML pages and calls `render.js` |
| `render.js` | Playwright screenshot renderer (transparent background for sprites) |
| `comparison.py` | Side-by-side sheets in `../comparison/` (all seven styles) |
| `fetch_fonts.sh` | Downloads the SIL OFL fonts from the `@fontsource` npm packages into `fonts/` (git-ignored) |

```bash
./fetch_fonts.sh
python3 build.py                       # all styles, all images
python3 build.py 02 --only=town_view   # one style, one image
python3 comparison.py
```

Requirements: Python 3.12+, Pillow, Node 18+ with `playwright` and its Chromium.
