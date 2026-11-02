# Naming & Asset Guide — 06 Ballpoint Sketch Fantasy · "The Inkbound Forge"

Conventions for files, sizes, paper textures, pivots and Godot 4.x import for this direction.
Numbers are tailored to blue pen linework on a separate, tiled squared-paper layer; see
[README](README.md) for the style and [prompts.md](prompts.md) for generation.

---

## 1. File naming

* `snake_case`, lowercase ASCII, no spaces, no dates, no version numbers in the name (Git tracks
  versions).
* Pattern: `<prefix>_<subject>[_<variant>][_<action>][_<dir>][_<frame>][_b<boil>].png`
* Frame numbers two digits from `01`. Directions `s`, `n`, `e`, `w` (`se`, `sw`, `ne`, `nw` reserved).
* **Boil variants** (re-traced copies of the same pose) get `_b1`, `_b2`, `_b3` after the frame:
  `chr_blacksmith_idle_s_01_b2.png`.

| Prefix | Category | Examples |
|---|---|---|
| `chr_` | Characters, NPCs, creatures | `chr_blacksmith_walk_s_04.png`, `chr_adventurer_idle_e_01_b1.png` |
| `eqp_` | Item icons, held/world versions | `eqp_sword_longsword_runed.png`, `eqp_armour_plate_anvil.png`, `eqp_sword_longsword_runed_held.png` |
| `env_` | Trees, props, terrain tiles | `env_tree_oak_02.png`, `env_prop_barrel_01.png`, `env_tiles_village.png` |
| `bld_` | Buildings: roofs, interiors, walls | `bld_smithy_roof.png`, `bld_smithy_interior.png`, `bld_inn_tipsy_wyvern_roof.png` |
| `bg_` | **Tileable background paper** | `bg_paper_grid_512.png`, `bg_paper_plain_512.png` |
| `ui_` | Interface elements | `ui_btn_sketch_normal.png`, `ui_btn_sketch_hover.png`, `ui_panel_tooltip_navy.9.png`, `ui_underline_red_01.png` |
| `fx_` | Effects, overlays, shader textures | `fx_sparks_forge_03.png`, `fx_select_circle_red_02.png`, `fx_hatch_night.png` |
| `map_` | Annotated plans and maps | `map_town_brindlewick.png`, `map_world_north.png` |

Rules:
* British spelling in names (`armour`, `colour`).
* Masters (512 px or larger) live under `_source/` with `_master`: `chr_blacksmith_master.png`.
  Only target-size exports go into `res://assets/`.
* Red-ink parts that need separate animation or tinting are their own layer/file with `_red`:
  `chr_adventurer_cloak_red_walk_s_03.png`, `eqp_sword_longsword_runed_gem_red.png`.
* Paper textures carry their pixel size in the name (`_512`, `_1024`) because the size defines the
  world scale of the grid (see §6).
* Sheets: `chr_blacksmith_walk_s_sheet.png` (frames left→right, equal size, no padding).

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
│   ├── buildings/             bld_*_roof.png, bld_*_interior.png, bld_*_walls.png
│   ├── backgrounds/           bg_paper_grid_512.png, bg_paper_plain_512.png
│   ├── maps/
│   ├── ui/
│   │   ├── sketch/            hand-drawn buttons, frames, underlines, arrows
│   │   └── theme/             inkbound_theme.tres
│   ├── fx/
│   └── fonts/                 *.ttf, *.tres (FontVariation), OFL.txt per family
├── shaders/                   paper_world.gdshader, line_boil.gdshader, night_hatch.gdshader,
│                              select_circle.gdshader
└── _source/                   (excluded from export) masters, .kra/.psd, generation sidecars
```

Add `_source/` to export exclusions (`Project → Export → Resources → Filters to exclude`).

---

## 3. Dimensions

**Reference resolution 1920×1080**, tile **64×64 px**, paper square **32×32 px**.

| Asset type | Master | In-game canvas | Notes |
|---|---|---|---|
| Characters | 512×512 | **128×128** | Body ≈ 64–80 px wide = 2–2.5 grid squares |
| Large creatures | 1024×1024 | 256×256 | |
| Item icons | 512×512 | **128×128** | 64 px in slots, 128 px in tooltips |
| Held items / world drops | 512×512 | 64×64 or 128×128 | |
| Trees | 512×512 | 192×192 or 256×256 | Canopy 3–4 tiles |
| Props | 256×256 | 64×64 – 128×128 | **Multiples of 32** (whole grid squares) |
| Buildings (roof, interior, walls) | 4× target | **Multiples of 64** | Smithy ≈ 256×192 (4×3 tiles), inn ≈ 384×256 (6×4) |
| Tilesets | 4× target | 64×64 per tile | |
| **Paper textures** | 512×512 | **512×512**, seamless | 16 × 16 squares of 32 px = 8 × 8 tiles |
| UI screens | 1920×1080 | 1920×1080 | |

### Line weight must be designed for target size

The 512 px masters use ~2 px lines and ~1 px hatching; a 4× reduction leaves 0.5 px lines and
0.25 px hatch — invisible. **Draw (or redraw) at target size** with these minimums:

| Element (at in-game size) | Minimum | Recommended |
|---|---|---|
| Actor / interactable silhouette (double pass) | 2 px | 2–3 px |
| Environment contour (single pass) | 1.5 px | 2 px |
| Interior detail | 1 px | 1–1.5 px |
| Hatch strokes | 1 px | 1 px, spacing ≥ 3 px |
| Construction lines (icons only) | 1 px at 30–40 % | — |
| Icon contour (128 px) | 1.5 px | 2 px |

For masters meant to be downscaled 4×, draw contours at ~8 px and hatching at ~4 px stroke / 12 px
spacing. Grid rules on the paper are **1 px at 1:1** and must never be thicker than hatch strokes.

---

## 4. Sprite orientation

* **Straight top-down**, camera looking directly down. Default facing: **south**.
* **4 directions (S, N, E, W)** are enough; the sketch look tolerates snapping, and pen frames are
  expensive. Diagonals use the nearest cardinal.
* **Mirroring:** don't make W by flipping E for asymmetric characters (single pauldron, eyepatch,
  hammer hand, tongs, red cloak clasp) — and flipping also moves the dense hatching to the lit side.
  Mirror only symmetric NPCs/props, or when shadow hatching comes from a shader.
* Icons: weapons 45° tip top-right; armour front view; consumables upright.

---

## 5. Scale consistency & grid alignment

* 1 tile = 64 px = **2 × 2 paper squares**; ≈ 1.3 × a human's shoulder width from above.
* Blacksmith at 128 px canvas: shoulders ≈ 80 px incl. pauldron (2.5 squares); adventurer ≈ 68 px.
* Doors 64 px wide, barrels ≈ 40 px, anvil ≈ 56×32 px, tree canopies 160–240 px.
* **Align to the grid, not to the pixels of the drawing:** building footprints, walls, fences and
  tile edges sit on grid lines (multiples of 32 px in world space). The paper's origin is the world
  origin `(0, 0)`, so a `TileMap` at the origin with 64 px cells lands exactly on every second rule.
  Characters and loose props are *not* snapped — they move freely; only their footprints should look
  plausible against the grid.
* Keep `_source/ref_scale_sheet.png` (blacksmith, adventurer, door, barrel, anvil, tree over
  `bg_paper_grid_512.png`) and check each new asset against it.
* Never fix size errors with node `scale`; fix the export.

---

## 6. Paper textures

| File | Size | Content | Use |
|---|---|---|---|
| `bg_paper_grid_512.png` (from `paper_grid.png`) | 512×512 | Off-white `#f7f6f0`, blue-grey 1 px rules, 32 px squares, subtle stitched noise | Default world ground (village, interiors, dungeons) |
| `bg_paper_plain_512.png` (from `paper_plain.png`) | 512×512 | Same paper, no rules | Wilderness, cut-scenes, accessibility toggle |

**Chosen world scale: 1 texture pixel = 1 world pixel, so 1 grid square = 32 px = half a 64 px
tile.** Reasons:
* Two squares per tile means tile edges always coincide with grid rules, so buildings and fences
  "sit on the paper" correctly, while the grid stays finer than the tiles and reads as notebook
  paper rather than a gameplay board.
* A character (64–80 px) spans 2–2.5 squares — the grid gives an instant, honest scale cue.
* 32 px squares stay visible at 1280×720 (≈ 21 px) without becoming dominant at 2560×1440 (≈ 43 px);
  64 px squares would read as a chessboard, 16 px squares as noise behind the hatching.
* 512 px = 16 squares = 8 tiles: power-of-two, cheap to repeat, and the seam always falls on a rule.

**Tiling rules**
* Seamless on all four edges; rule positions identical on opposite edges; no brightness drift.
* Repeat in **world space** (see README *Paper & layer architecture*) — `Parallax2D`
  (`repeat_size = Vector2(512, 512)`, `scroll_scale = Vector2(1, 1)`), a large `Sprite2D` with
  `region_enabled = true` and `region_rect` the size of the level, or a shader on the bottom
  `CanvasLayer` that samples at world coordinates.
* Origin at world `(0, 0)`, never offset by half a square.
* Menus and full-screen UI may use screen-space paper (`TextureRect`, `stretch_mode = Tile`).

**Godot import & repeat**
* In Godot 4, texture repeat is **not** an import option (it was in Godot 3). Enable it on the node
  that draws the paper: `CanvasItem.texture_repeat = Enabled` (not `Mirror`, which flips the
  stitched noise and the rule offsets), or in a shader with
  `uniform sampler2D paper : repeat_enable, filter_linear_mipmap;`.
* Import: `compress/mode = Lossless`, `mipmaps/generate = true` (the paper is the one texture that is
  often seen zoomed out, where 1 px rules moiré without mipmaps), filter **Linear Mipmap**
  (`texture_filter` on the paper node).
* Never multiply the paper over sprites; sprites occlude it with their opaque fills.

---

## 7. Transparency

* PNG, RGBA, **straight (non-premultiplied) alpha**.
* Background around the subject fully transparent. **No white matte:** anti-aliased edge pixels
  carry ink colour (`#1f3a93` / `#c62828`) with partial alpha, not ink blended toward white —
  otherwise a white halo shows on the night hatch and on darker floors.
* **The pale interior fill is intentional and opaque (alpha 255).** It is what stops the grid at the
  silhouette; never key it out or reduce it to "paper showing through". Only exterior white (from
  white-background generations) is removed.
* Hatched ground shadows: blue strokes on transparency, no fill under them, so the paper shows
  between the strokes.
* **No paper, grid, grain or page edge baked into any sprite, icon or UI element**; paper exists only
  in `bg_*` files and full-screen backgrounds.
* Construction lines are partially transparent strokes (30–40 % alpha), never grey pixels.
* Don't trim at export (pivots stay stable); let the atlas packer trim.

---

## 8. Pivot & anchoring

| Asset | Pivot (anchor) | Godot setup |
|---|---|---|
| Characters | Feet centre (≈ y 0.80 of canvas) | `Sprite2D.centered = true`, `offset.y = -(0.30 × h)` so the origin is at the feet; Y-sort uses origin |
| Trees | Trunk base | Origin at trunk base; canopy above; canopy may fade when the player is behind |
| Buildings | Bottom-centre of footprint, on a grid line | Roof and interior share one origin; roof `modulate.a` fades when the player enters |
| Props | Bottom-centre of footprint | Footprint snapped to 32 px |
| Icons | Centre | `centered = true`, no offset |
| Paper | World `(0, 0)` | See §6 |
| FX / red interaction marks | Centre / target's feet | Red select circle sits under the feet, above the ground shadow |

Y-sort: `y_sort_enabled` on the world `Node2D` and object `TileMapLayer`s; feet/footprint origins
make ordering correct without per-sprite tweaks.

---

## 9. Godot 4.x import recommendations

**Textures (sprites, icons, buildings, UI)**
* Filter **Linear** (`Rendering → Textures → Canvas Textures → Default Texture Filter`): anti-aliased
  pen lines, not pixel art.
* Mipmaps **off** at 1:1; **on** (`Linear Mipmap`) for zoomed-out views (world map, camera zoom
  < 0.6) and always for the paper.
* Compression **Lossless**. VRAM formats smear 1 px pen strokes and hatching into blocks; lossy WebP
  (quality ≥ 0.9) only for full-screen backgrounds.
* `process/fix_alpha_border = true`, `process/premult_alpha = false`.

**World rendering**
* **Paper:** bottom `CanvasLayer` (`layer = -10`), world-anchored as in §6 (`paper_world.gdshader`
  or `Parallax2D`). Swap grid/plain by changing one texture.
* **Line boil:** `AnimatedSprite2D` cycling `_b1`–`_b3` variants at 8–10 fps, or
  `line_boil.gdshader` (UV-noise displacement, re-seeded every 2–3 frames); red-ink layers boil
  every frame.
* **Night:** `night_hatch.gdshader` on a `CanvasLayer` above the world adds screen-aligned hatch by
  darkness; forge `PointLight2D` masks it out; mild `CanvasModulate` (≈ `#c9cfe0`).
* **Interaction:** `fx_select_circle_red_*` (hand-drawn `#c62828` ring, boiled) under the target plus
  a Patrick Hand prompt ("E — Talk"); no glow outlines.
* Characters: `AnimatedSprite2D` + `SpriteFrames` (`<name>_frames.tres`), animations `idle_s`,
  `walk_s`, `work_s`, … at 8–12 fps.
* Tiles: `TileMapLayer`, 64×64 `TileSet`, origin at world `(0, 0)` so cells align with the paper grid.

**Window & UI**
* Viewport 1920×1080, **stretch mode `canvas_items`**, aspect `expand`. Test at 1280×720 (pen lines
  and grid must survive) and 2560×1440.
* One **`Theme`** (`res://assets/ui/theme/inkbound_theme.tres`): default font Patrick Hand 20 px
  (min 18); type variations `TitleLabel` (Caveat 700, MSDF), `HeadingLabel` (Architects Daughter
  34 px), `DialogueLabel` (Patrick Hand 22 px), `StatLabel` (Kalam 700, right-aligned in
  fixed-width containers — no tabular figures available). `StyleBoxTexture` 9-slices of hand-drawn
  blue frames on transparent backgrounds; dark tooltip `StyleBoxFlat` in navy ink (≈ `#16224a`) with
  the light rarity set; ink-dark rarity set on paper (README tables).
* Fonts: import as `FontFile`; MSDF only for Caveat; hinting Light (or None) for the handwriting faces.
