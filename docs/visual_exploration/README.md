# Blacksmith Game — Visual Style Exploration

This package compares **five distinct graphical directions** for our Godot 4.x fantasy blacksmith game, so we can choose the game's artistic identity before full visual production begins.

All five directions show the **same subjects with the same framing**:

- the protagonist (an older, heavyset retired adventurer who runs the village smithy)
- a visiting adventurer
- a sword and a set of armour
- a tree
- the same village map
- a main menu
- a typography sheet

The only thing that changes between directions is the rendering, the palette, the proportions and the UI language, so the differences are easy to compare.

> **Game context:** straight top-down 2D (the camera looks straight down: tops of heads, shoulders, roofs and tree canopies). The game is set in a small medieval fantasy village in a D&D-inspired world: the blacksmith workshop, the neighbouring inn, adventurers, villagers, forests and wilderness. The intended tone is warm and lived-in, with mystery and occasional darkness.

---

## How the example graphics were made (read first)

No AI image-generation model was available in the build environment. Rather than leave empty placeholders, **every example image was illustrated procedurally**:

- Python generates the SVG.
- Headless Chromium rasterises it to PNG.
- The source is in [`_generator/`](_generator/).

The same subject geometry (`subjects.py`, `town.py`) is passed through five style "painters" (`styles.py`, `svgcore.py`). This keeps the subjects identical and makes the comparison fair.

- **What the images reliably show:** palette, value structure, outline language, shading logic, lighting mood, proportions, top-down readability, UI and typography. That is enough to judge and choose a direction.
- **What they don't show:** final production polish. Brush work, painterly texture and fine illustration detail will be much richer in real assets. Each style's `prompts.md` contains the master prompt and the eight per-asset prompts for producing production-quality versions with an image model, or for briefing an artist.
- **Reference images:** the brief mentions four previously supplied reference images, but none were found in this repository. The directions were built from the written brief. If the references are added later, re-check each `prompts.md` against them; the prompts describe techniques, not camera angles, so they should adapt easily.

All eight graphics exist for all five directions (40 images). **No image files remain ungenerated.**

---

## The five directions

| # | Folder | Visual direction | Working title | Short description |
|---|---|---|---|---|
| 1 | [`01_gothic_noir/`](01_gothic_noir/) | Gothic Noir Top-Down | **Embers of the Forgotten** | Heavy black ink, hatching, exaggerated silhouettes, cold night world lit by warm forge-light (technique inspired by *Darkest Dungeon*) |
| 2 | [`02_warm_storybook/`](02_warm_storybook/) | Warm Storybook Village | **The Old Anvil** | Mature hand-painted storybook look: soft gradients, paper grain, coloured outlines, golden-hour warmth |
| 3 | [`03_bold_adventure/`](03_bold_adventure/) | Bold Readable Adventure Sim | **Forged Fortunes** | Thick navy outlines, flat cel shading, vibrant but controlled colour, maximum gameplay clarity |
| 4 | [`04_ink_parchment/`](04_ink_parchment/) | Ink-and-Parchment Fantasy | **The Smith's Chronicle** | Sepia ink, cross-hatching, pale washes, manuscript and map dressing on parchment |
| 5 | [`05_production_light/`](05_production_light/) | Production-Light Indie Fantasy | **Anvil & Ale** | No outlines, two-tone flat shapes, strict palette, modular, built for a small team |

Each folder contains:

| File | Contents |
|---|---|
| `blacksmith.png`, `adventurer.png`, `sword.png`, `armor.png`, `tree.png` | 512×512 transparent sprites / icons |
| `town_view.png`, `menu_screen.png`, `font_reference.png` | 1920×1080 complete compositions |
| `README.md` | Visual identity, rendering techniques, palette, lighting, proportions, top-down suitability, sprite and animation production, pros and cons, difficulty estimate, **typography system** |
| `prompts.md` | Master style prompt, eight detailed per-asset prompts, technical requirements, transparency and framing rules, consistency guidance |
| `naming_guide.md` | Filenames, dimensions, orientation, scale, transparency, pivots and anchoring, Godot import settings |

---

## Comparison table

Ratings run from 1 (low) to 5 (high). For **production complexity** and **animation difficulty**, a higher number means *harder*.

| Criterion | 01 Gothic Noir | 02 Warm Storybook | 03 Bold Adventure | 04 Ink & Parchment | 05 Production-Light |
|---|---|---|---|---|---|
| **Artistic identity** | Very strong, instantly recognisable; owns "darkness + forge-light" | Strong and charming; the familiar "cosy fantasy" market | Clear but more conventional; risk of looking like mobile or casual games | Very distinctive; rare in top-down games | Moderate; needs signature touches to avoid looking generic |
| **Atmosphere** | Moody, mysterious, dangerous; warmth lives only at the forge | Welcoming, nostalgic, warm, lived-in | Upbeat, energetic, adventurous | Scholarly, mythic, "a legend being written" | Friendly, cosy, light |
| **Readability (top-down gameplay)** | 3 – outlines help, but night palettes and fog hurt; needs lighting discipline | 3 – soft edges blend into painted ground; needs contrast management | **5** – best silhouettes and separation | 3 – low value contrast on parchment; actors need heavier lines and colour washes | 4 – clean shapes, but missing outlines need careful value separation |
| **Production complexity** | 4 | 4 | 3 | 4 | **2** |
| **Animation difficulty** | 4 (ink and hatching must stay consistent per frame; can be eased with shader outlines and Light2D) | 4 (painted frames are costly, so use cut-out / skeletal rigs) | 3 (clean shapes suit cut-out or modest frame-by-frame) | 4 (line work and hatching per frame; "line boil" can become a feature) | **2** (two-tone shapes, modular rigs, palette swaps) |
| **Typography** | Grenze Gotisch / Grenze / Alegreya Sans | Uncial Antiqua / Alegreya / Nunito | Cinzel Decorative / Signika | IM Fell English SC / IM Fell English / EB Garamond | Bree Serif / Source Sans 3 |
| **Rarity colours** | Excellent on near-black UI; Legendary orange sits close to forge glow | Good on dark wood; parchment panels need darker variants | Excellent with navy text outline on any background | Needs two sets (ink-dark on parchment, light on dark tooltips) | Good on the plum UI; Legendary is close to the amber accent |
| **Relative art cost** (Production-Light = 1.0) | ≈ 1.9 | ≈ 1.6 | ≈ 1.4 | ≈ 1.6 | **1.0** |
| **Suitability for this game** | High for a darker, story-driven game; fits the "retired adventurer with a past" angle best | **Very high**: matches the warmth, personality and lived-in village of the brief, and keeps room for darkness | High for a systems/crafting-heavy game where equipment readability is crucial | High for a narrative/lore game; the map-like top-down view fits naturally | High when budget and schedule matter most; easiest to scale to a full game |

**About the cost figures:** each style README contains a detailed person-month estimate, but those estimates were scoped independently. For example, the Bold Adventure estimate assumes eight-direction characters, while the others assume four. The *relative art cost* row above normalises them to the same scope (four directions, the same asset counts). Use it to compare the directions; use the per-style tables for that style's own breakdown.

### Observations to guide the decision

- **The brief's tone** (warmth, personality, mystery, occasional darkness, lived-in) is covered most completely by **02 Warm Storybook**. **01 Gothic Noir** delivers the mystery and darkness best but sacrifices day-to-day warmth.
- **Gameplay clarity** in a crafting and equipment game favours **03 Bold Adventure**. Its outline-and-cel language also makes item tiers and rarity instantly readable.
- **04 Ink & Parchment** is the most original identity and turns the top-down camera into a strength, because the world reads as a living map. It needs extra work on actor contrast.
- **05 Production-Light** is the safe production bet. A useful hybrid is possible: keep Production-Light's modular two-tone pipeline for the world and characters, and borrow one signature layer from another direction, such as Storybook UI and lighting or Ink & Parchment maps and menus.
- **Combining directions works best by layer**, not by mixing rendering techniques on the same object. For example, use one direction for the world, another for UI and menus, and another for codex or map screens.

---

## Visual comparison index

### Side-by-side sheets

| Asset | Comparison sheet |
|---|---|
| Blacksmith | [comparison/blacksmith_comparison.png](comparison/blacksmith_comparison.png) |
| Adventurer | [comparison/adventurer_comparison.png](comparison/adventurer_comparison.png) |
| Sword | [comparison/sword_comparison.png](comparison/sword_comparison.png) |
| Armour | [comparison/armor_comparison.png](comparison/armor_comparison.png) |
| Tree | [comparison/tree_comparison.png](comparison/tree_comparison.png) |
| Town view | [comparison/town_view_comparison.png](comparison/town_view_comparison.png) |
| Menu screen | [comparison/menu_screen_comparison.png](comparison/menu_screen_comparison.png) |
| Font reference | [comparison/font_reference_comparison.png](comparison/font_reference_comparison.png) |

![Blacksmith comparison](comparison/blacksmith_comparison.png)
![Town view comparison](comparison/town_view_comparison.png)
![Menu comparison](comparison/menu_screen_comparison.png)

### All example images

| Asset | 01 Gothic Noir | 02 Warm Storybook | 03 Bold Adventure | 04 Ink & Parchment | 05 Production-Light |
|---|---|---|---|---|---|
| Blacksmith | [png](01_gothic_noir/blacksmith.png) | [png](02_warm_storybook/blacksmith.png) | [png](03_bold_adventure/blacksmith.png) | [png](04_ink_parchment/blacksmith.png) | [png](05_production_light/blacksmith.png) |
| Adventurer | [png](01_gothic_noir/adventurer.png) | [png](02_warm_storybook/adventurer.png) | [png](03_bold_adventure/adventurer.png) | [png](04_ink_parchment/adventurer.png) | [png](05_production_light/adventurer.png) |
| Sword | [png](01_gothic_noir/sword.png) | [png](02_warm_storybook/sword.png) | [png](03_bold_adventure/sword.png) | [png](04_ink_parchment/sword.png) | [png](05_production_light/sword.png) |
| Armour | [png](01_gothic_noir/armor.png) | [png](02_warm_storybook/armor.png) | [png](03_bold_adventure/armor.png) | [png](04_ink_parchment/armor.png) | [png](05_production_light/armor.png) |
| Tree | [png](01_gothic_noir/tree.png) | [png](02_warm_storybook/tree.png) | [png](03_bold_adventure/tree.png) | [png](04_ink_parchment/tree.png) | [png](05_production_light/tree.png) |
| Town view | [png](01_gothic_noir/town_view.png) | [png](02_warm_storybook/town_view.png) | [png](03_bold_adventure/town_view.png) | [png](04_ink_parchment/town_view.png) | [png](05_production_light/town_view.png) |
| Menu screen | [png](01_gothic_noir/menu_screen.png) | [png](02_warm_storybook/menu_screen.png) | [png](03_bold_adventure/menu_screen.png) | [png](04_ink_parchment/menu_screen.png) | [png](05_production_light/menu_screen.png) |
| Font reference | [png](01_gothic_noir/font_reference.png) | [png](02_warm_storybook/font_reference.png) | [png](03_bold_adventure/font_reference.png) | [png](04_ink_parchment/font_reference.png) | [png](05_production_light/font_reference.png) |

### Shared subject definitions (identical across directions)

- **Blacksmith ("Old Brannoc"):** seen from straight above, facing south. He has a bald, scarred scalp with a grey fringe, an eyepatch strap, and a large grey braided beard with a gold ring. He wears a leather apron over a big belly, has one old steel adventuring pauldron and leather bracers, holds a sledgehammer in his right hand and carries tongs at his hip.
- **Adventurer:** the same proportion system, but slimmer. A round shield is slung over the cloak, with a ponytail, pauldrons and a leather jerkin. A drawn sword is held point-forward and a dagger hangs at the hip.
- **Sword:** inventory icon on a 45° diagonal with the tip at top-right. Fullered blade, curled gold guard, central gem, wrapped grip.
- **Armour:** front-view inventory icon. Breastplate with an anvil emblem, gorget, three-lame pauldrons, faulds and tassets.
- **Tree:** a deciduous canopy of clustered foliage seen from above, with its cast shadow toward bottom-right.
- **Town (Brindlewick):** the same map in every direction.
  - Crossroads square with a well and market stall.
  - The smithy with its open forge yard (SW).
  - *The Tipsy Wyvern* inn, L-shaped, with a stable and beer garden (NE).
  - Cottages, a chapel, a stream with a bridge (E) and forest edges (N/W).
  - Villagers, the blacksmith at his anvil, and an adventurer arriving.
- **Lighting convention:** key light from the top-left in every direction. Each direction's own time of day: Gothic = night, Storybook = golden afternoon, Bold = midday, Ink = drawn map, Production-Light = neutral day.

---

## Typography at a glance

All fonts are SIL Open Font License (Google Fonts) and work in Godot 4 as `.ttf`, `.otf` or `.woff2` `FontFile` resources. The rarity families (white, blue, yellow, orange, gold/brown, green) are tuned per direction; see each `font_reference.png` and the README's Typography section.

| Direction | Title | Headings / dialogue | UI / body | Numbers |
|---|---|---|---|---|
| 01 Gothic Noir | Grenze Gotisch | Grenze | Alegreya Sans | Alegreya Sans (tnum) |
| 02 Warm Storybook | Uncial Antiqua | Alegreya | Nunito | Nunito (tnum) |
| 03 Bold Adventure | Cinzel Decorative | Signika | Signika | Signika (tnum) |
| 04 Ink & Parchment | IM Fell English SC | IM Fell English | EB Garamond | EB Garamond (lnum + tnum) |
| 05 Production-Light | Bree Serif | Bree Serif | Source Sans 3 | Source Sans 3 (tnum) |

| Rarity | 01 | 02 | 03 | 04 (parchment / dark tooltip) | 05 |
|---|---|---|---|---|---|
| Common (white) | `#d8d4cc` | `#f6efe0` | `#ffffff` | `#2b1d12` / `#efe4cc` | `#f2f0ec` |
| Magic (blue) | `#7b93ff` | `#86aeff` | `#4f8fff` | `#284a9e` / `#86a4f0` | `#6ea4ff` |
| Rare (yellow) | `#f2d65a` | `#f8dc66` | `#ffe14a` | `#8e6e00` / `#f0d060` | `#ffd84a` |
| Legendary (orange) | `#ff8a30` | `#ffa046` | `#ff8a1f` | `#b44a14` / `#f09050` | `#ff9634` |
| Unique (gold/brown) | `#c9a35a` | `#d8ae66` | `#e2b464` | `#6e4e22` / `#d4aa6a` | `#cfa66a` |
| Set (green) | `#45d46e` | `#82d870` | `#46e070` | `#2c7438` / `#7ccc80` | `#5cd274` |

---

## Regenerating the examples

See [`_generator/README.md`](_generator/README.md). In short:

```bash
cd docs/visual_exploration/_generator
./fetch_fonts.sh            # downloads the OFL fonts (not committed)
python3 build.py            # renders all 40 images (needs Node + Playwright Chromium)
python3 comparison.py       # rebuilds the comparison sheets
```
