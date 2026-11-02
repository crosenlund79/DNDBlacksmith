# Naming & Asset Guide — 04 Ink-and-Parchment Fantasy · "The Smith's Chronicle"

Conventions for files, sizes, pivots and Godot 4.x import for this direction. Numbers are tailored
to fine ink linework on a parchment ground; see [README](README.md) for the style itself and
[prompts.md](prompts.md) for generation.

---

## 1. File naming

* `snake_case`, lowercase ASCII, no spaces, no dates, no version numbers in the name (Git tracks
  versions).
* Pattern: `<prefix>_<subject>[_<variant>][_<action>][_<dir>][_<frame>].png`
* Frame numbers are two digits, starting at `01`. Directions: `s`, `n`, `e`, `w` (`se`, `sw`, `ne`,
  `nw` reserved if 8-direction is ever needed).

| Prefix | Category | Examples |
|---|---|---|
| `chr_` | Characters, NPCs, creatures | `chr_blacksmith_walk_s_04.png`, `chr_adventurer_idle_e_01.png`, `chr_wolf_grey_run_w_03.png` |
| `eqp_` | Items, weapons, armour (icons and held/world versions) | `eqp_sword_longsword_runed.png`, `eqp_armour_plate_anvil.png`, `eqp_sword_longsword_runed_held.png` |
| `env_` | Terrain, trees, props, tiles | `env_tree_oak_02.png`, `env_prop_barrel_01.png`, `env_tiles_village.png` |
| `bld_` | Buildings, roofs, interiors | `bld_smithy_roof.png`, `bld_inn_tipsy_wyvern.png`, `bld_chapel.png` |
| `ui_` | Interface, fonts sheets, ornaments | `ui_menu_chronicle_bg.png`, `ui_initial_t_rubric.png`, `ui_fleuron_01.png`, `ui_btn_hover.png` |
| `fx_` | Effects, overlays, shader textures | `fx_sparks_forge_03.png`, `fx_paper_grain.png`, `fx_hatch_overlay.png`, `fx_select_ring_02.png` |
| `map_` | Illustrated maps (world, town, quest) | `map_town_overview.png`, `map_world_region_north.png` |

Rules:
* Use British spelling consistently in names (`armour`, `colour`).
* Masters (512 px or larger source) live outside `res://` or under `_source/` and carry `_master`:
  `chr_blacksmith_master.png`. Only target-size exports go into the game folders.
* Sprite sheets: `chr_blacksmith_walk_s_sheet.png` (frames left→right, same frame size, no padding
  unless stated in the `.tres`).

---

## 2. Folder layout (`res://`)

```text
res://
├── assets/
│   ├── characters/
│   │   ├── blacksmith/        chr_blacksmith_*.png, blacksmith_frames.tres (SpriteFrames)
│   │   └── adventurer/
│   ├── equipment/
│   │   ├── icons/             eqp_*.png (128x128)
│   │   └── held/              eqp_*_held.png
│   ├── environment/
│   │   ├── trees/
│   │   ├── props/
│   │   └── tilesets/          env_tiles_*.png + *.tres (TileSet)
│   ├── buildings/
│   ├── maps/
│   ├── ui/
│   │   ├── ornaments/         initials, fleurons, cartouches, borders
│   │   ├── menu/
│   │   └── theme/             chronicle_theme.tres
│   ├── fx/
│   │   └── overlays/          fx_paper_grain.png, fx_hatch_overlay.png
│   └── fonts/                 *.ttf, *.tres (FontVariation), OFL.txt per family
├── shaders/                   paper_overlay.gdshader, line_boil.gdshader, night_hatch.gdshader,
│                              actor_outline.gdshader
└── _source/                   (excluded from export) 512px masters, .kra/.psd, generation sidecars
```

Add `_source/` to export exclusions (`Project → Export → Resources → Filters to exclude`).

---

## 3. Dimensions

**Reference resolution 1920×1080**, tile **64×64 px**.

| Asset type | Master | In-game canvas | Notes |
|---|---|---|---|
| Characters | 512×512 | **128×128** | Body ≈ 64–80 px wide, i.e. 1–1.25 tiles |
| Large creatures | 1024×1024 | 256×256 | |
| Item icons | 512×512 | **128×128** | Shown at 64 px in slots on small UI; 128 px in tooltips |
| Held items / world drops | 512×512 | 64×64 or 128×128 | |
| Trees | 512×512 | 192×192 or 256×256 | Canopy spans 3–4 tiles |
| Props (barrel, anvil, crate) | 256×256 | 64×64 – 128×128 | Multiples of 32 |
| Buildings | 4× target | **Multiples of 64** | Smithy ≈ 256×192 (4×3 tiles), inn ≈ 384×256 (6×4) |
| Tilesets | 4× target | 64×64 per tile | |
| UI screens / maps | 1920×1080 (or 3840×2160) | 1920×1080 | |
| Ornaments (initials, fleurons) | vector or 4× | as used | Initial ≈ 96–128 px tall |
| Paper overlay texture | — | 1024×1024, tileable | |

### Line weight must be designed for target size

The 512 px masters use 2.4 px ink lines and 1.1 px hatching. A straight 4× reduction gives 0.6 px
lines and 0.28 px hatch — they disappear or turn to grey mush. **Draw (or redraw) at target scale**
with these minimums:

| Element (at in-game size) | Minimum | Recommended |
|---|---|---|
| Actor outer contour (characters, interactables) | 2 px | 2–3 px |
| Environment outline | 1.5 px | 2 px |
| Interior detail lines | 1 px | 1–1.5 px |
| Hatch lines | 1 px | 1 px, pitch ≥ 3 px (−35°/+35°) |
| Icon outline (128 px) | 1.5 px | 2 px |

Equivalent at the 512 px master: draw actor contours at ~8–10 px and hatching at ~4 px line /
12 px pitch if the master is meant to be downscaled 4×. Alternatively keep masters fine and only
apply hatching via the screen-space hatch shader.

---

## 4. Sprite orientation

* **Straight top-down**, camera looking directly down. Default facing: **south** (down the screen).
* **4 directions (S, N, E, W) are sufficient** for this style: the map-like look tolerates it and
  the line-art cost per frame is high. Diagonal movement uses the nearest cardinal sprite.
* **Mirroring caveats:** don't generate W by flipping E for asymmetric characters — the blacksmith's
  single pauldron, eyepatch, hammer hand and tongs would swap sides, and the −35° hatching and
  top-left lighting would flip to the wrong side. Mirror only symmetric NPCs/props *and* if hatching
  comes from the screen-space shader rather than the texture.
* Icons: weapons 45° diagonal tip top-right; armour front view; consumables upright.

---

## 5. Scale consistency

* 1 tile = 64 px ≈ 1.3 × a human's shoulder width seen from above.
* Blacksmith at 128 px canvas: shoulders ≈ 80 px including pauldron; adventurer ≈ 68 px.
* Doors 64 px wide, barrels ≈ 40 px diameter, anvil ≈ 56×32 px, tree canopies 160–240 px.
* Keep `_source/ref_scale_sheet.png` (blacksmith, adventurer, door, barrel, anvil, tree on a 64 px
  grid) and check every new asset against it before import.
* Never scale sprites in the scene to fix size errors (`scale` stays `(1, 1)`); fix the export.

---

## 6. Transparency

* PNG, RGBA, **straight (non-premultiplied) alpha**.
* Ink lines **anti-aliased**; keep the semi-transparent ink edge pixels in ink colour (`#2b1d12`), not
  blended toward white or parchment — otherwise halos appear on darker ground or at night.
* **No parchment, paper grain or vignette baked into sprites**; paper comes from the background and
  the overlay shader. Exceptions: `map_*` and full-screen `ui_*` backgrounds.
* Washes may be semi-transparent (≈ 90 % opacity) to let ground tint through, matching the examples.
* Trim nothing at export (keep the canvas so pivots stay stable); Godot's atlas packer can trim.

---

## 7. Pivot & anchoring

| Asset | Pivot (anchor) | Godot setup |
|---|---|---|
| Characters | Feet centre (between boots, ≈ y 0.80 of canvas) | `Sprite2D.centered = true`, `offset.y = -(0.30 × h)` so the node origin is at the feet; Y-sort uses origin |
| Trees | Trunk base | Origin at trunk base; canopy drawn above; separate canopy layer may fade when player is behind |
| Buildings | Bottom-centre of footprint | Origin at south wall centre; collision = footprint polygon |
| Props | Bottom-centre of footprint | Same as buildings |
| Icons | Centre | `centered = true`, no offset |
| FX | Centre (or emitter point) | |

Y-sort: enable `y_sort_enabled` on the world `Node2D` / `TileMapLayer` parents; origins at
feet/footprint make ordering correct without per-sprite tweaks.

---

## 8. Godot 4.x import recommendations

**Textures (sprites, icons, buildings)**
* Filter: **Linear** (`Project Settings → Rendering → Textures → Canvas Textures → Default Texture
  Filter = Linear`). This is drawn art with anti-aliased lines, not pixel art.
* Mipmaps: **off** for sprites at 1:1 (default camera zoom). Turn on (`Linear Mipmap`) only for assets
  shown zoomed out (world map, zoomed-out camera > 0.6× scale) to prevent hatch moiré.
* Compression: **Lossless** (`compress/mode = Lossless`). VRAM-compressed formats (ETC2/BPTC/S3TC)
  smear 1 px ink lines and hatching into blocks. Lossy WebP is acceptable only for full-screen
  backgrounds (`map_*`, menu) at quality ≥ 0.9.
* `process/fix_alpha_border = true`, `premult_alpha = false`.

**World rendering**
* **Paper overlay:** a `CanvasLayer` (layer above the world, below the HUD) with a full-screen
  `ColorRect` running `paper_overlay.gdshader` that multiplies `fx_paper_grain.png` (tileable,
  1024², screen-space or world-space-anchored) over everything. One texture for all sprites.
* **Line boil:** `line_boil.gdshader` on actors — small UV noise displacement re-seeded at 8–12 fps.
* **Night/hatch:** `night_hatch.gdshader` + `CanvasModulate` + additive `PointLight2D` (forge
  `#c8641e`) that masks the hatch overlay inside light radius.
* **Actor outline/selection:** `actor_outline.gdshader` for a rubric-red `#a8321e` hover outline, or
  a `fx_select_ring_*` sprite under the feet.
* Characters: `AnimatedSprite2D` with `SpriteFrames` resources (`<name>_frames.tres`), animations
  named `idle_s`, `walk_s`, `work_s`, … at 8–12 fps.
* Tiles: `TileMapLayer` with 64×64 `TileSet`, Y-sort enabled on object layers.

**Window & UI**
* `display/window/size/viewport_width/height = 1920×1080`, **stretch mode `canvas_items`**, aspect
  `expand`. Test at 1280×720 (fine lines must survive) and 2560×1440.
* One project **`Theme`** (`res://assets/ui/theme/chronicle_theme.tres`): default font EB Garamond
  18 px; type variations `TitleLabel` (IM Fell English SC, MSDF), `HeadingLabel` (IM Fell English
  36 px), `DialogueLabel` (IM Fell English 24 px), `StatLabel` (EB Garamond `FontVariation` with
  `lnum` + `tnum`); `StyleBoxTexture` panels using parchment 9-slices with ink borders; dark
  tooltip `StyleBoxFlat` `#241a12`, rarity colours per README tables.
* Fonts: import as `FontFile`; MSDF only for the title font; hinting Light for EB Garamond, None/Light
  for IM Fell.
