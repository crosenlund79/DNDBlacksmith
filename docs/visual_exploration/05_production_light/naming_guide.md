# 05 · Production-Light Indie Fantasy — "Anvil & Ale" · Naming & Asset Guide

Conventions for files, folders, sizes, pivots and Godot 4.x import settings for this direction.
All numbers are tuned to the flat two-tone vector style described in [README.md](README.md)
(no outlines, anti-aliased edges, SVG masters exported to PNG).

---

## 1. Key decisions at a glance

| Decision | Value | Why |
|----------|-------|-----|
| Tile size | **48 × 48 px** | Flat vector art needs a little more room than pixel art to keep signature details (beard ring, eyepatch strap, shield boss) readable; 32 px would force pixel-art simplification, which this style is not. 48 divides cleanly into 1280×720 (≈ 27 × 15 tiles) and scales 1.5× to 1080p. |
| Character cell | **96 × 96 px** (2 × 2 tiles) | Character body ≈ 1 tile wide; the extra space holds weapons, hammer swings and shadows without changing cell size between animations. |
| Large characters / creatures | 144 × 144 or 192 × 192 | multiples of 48 |
| Inventory icons | **64 × 64** (1×), **128 × 128** (HiDPI) | exported from the same SVG |
| Base viewport | **1280 × 720**, stretch to 1920 × 1080 and beyond | |
| Texture filter | **Linear** | anti-aliased vector art, not pixel art |
| Masters | SVG (or `.afdesign`) kept in `art_src/`, never in `res://` | re-export at @2x for 4K without redrawing |

---

## 2. File naming

- `snake_case`, lowercase ASCII, no spaces, no dates, no version numbers in names (use git).
- Pattern: `<prefix>_<subject>[_<variant>][_<action>][_<dir>][_<layer>][_<frame>].<ext>`
- Frame numbers are two digits, starting at `01`. Spritesheets drop the frame number and add
  `_sheet`.

### Prefixes

| Prefix | Category | Examples |
|--------|----------|----------|
| `chr_` | characters & creatures | `chr_blacksmith_idle_s_01.png`, `chr_villager_a_walk_n_03.png` |
| `eqp_` | equipment (paper-doll layers and icons) | `eqp_sword_longsword_icon.png`, `eqp_pauldron_old_steel_l.png` |
| `env_` | terrain, tiles, vegetation, props | `env_tree_oak_01.png`, `env_tiles_grass_road.png`, `env_prop_barrel_01.png` |
| `bld_` | buildings & building parts | `bld_smithy_roof.png`, `bld_inn_tipsy_wyvern_walls.png` |
| `ui_` | interface | `ui_button_primary_hover.png`, `ui_icon_gold.png`, `ui_frame_rarity_legendary.png` |
| `fx_` | effects | `fx_spark_01.png`, `fx_forge_smoke_sheet.png` |
| `fnt_` | fonts (if renamed) | `fnt_bree_serif.ttf` |

### Direction suffixes

| Suffix | Facing | Notes |
|--------|--------|-------|
| `_s` | south (down-screen) | default / idle reference |
| `_n` | north | |
| `_w` | west | |
| `_e` | east | normally **not exported** — W flipped in engine. Export only when an asymmetric character (the blacksmith) needs it. |

### Action names

`idle`, `walk`, `run`, `hammer`, `attack`, `hit`, `use`, `carry`, `sit`, `drink`, `talk`.

Examples: `chr_blacksmith_walk_s_04.png` (frame 4 of 6), `chr_blacksmith_hammer_w_sheet.png`,
`chr_adventurer_attack_n_02.png`.

### Paper-doll layer suffixes

Layers are exported per direction, unanimated if the rig moves them.

| Suffix | Layer | Draw order (back → front, facing S) |
|--------|-------|--------------------------------------|
| `_back` | shield, cloak, quiver | 1 |
| `_body` | torso/base body | 2 |
| `_legs` | boots/feet | 3 (under body when facing S) |
| `_torso` | apron, jerkin, armour | 4 |
| `_shoulder_l` / `_shoulder_r` | pauldrons (character's left/right) | 5 |
| `_hand_l` / `_hand_r` | hands, bracers | 6 |
| `_weapon` / `_offhand` | held items | 7 |
| `_head` | scalp/face top | 8 |
| `_hair` / `_beard` / `_hat` | head attachments | 9 |
| `_shadow` | shape-shadow overlay (optional, see §5) | above its part |

Example: `chr_blacksmith_s_beard.png`, `eqp_pauldron_old_steel_s_shoulder_l.png`.
Equipment that is both icon and layer: `eqp_<item>_icon.png` + `eqp_<item>_<dir>_<layer>.png`.

### Palette variants

Do not export colour variants — use the palette-swap shader. Palettes live as 1-pixel-tall PNG
rows: `chr_palette_villager_01.png` … or one atlas `chr_palette_villagers.png` (one row per variant).

---

## 3. `res://` folder layout

```
res://
├── assets/
│   ├── characters/
│   │   ├── blacksmith/        chr_blacksmith_*.png, blacksmith_frames.tres
│   │   ├── adventurers/
│   │   ├── villagers/         shared body template + layers
│   │   └── creatures/
│   ├── equipment/
│   │   ├── icons/             eqp_*_icon.png (64) and @2x (128) in icons_2x/
│   │   └── layers/            eqp_*_<dir>_<layer>.png
│   ├── environment/
│   │   ├── tiles/             env_tiles_*.png + *.tres TileSets
│   │   ├── vegetation/
│   │   └── props/
│   ├── buildings/             bld_* (walls, roofs, doors as separate sprites)
│   ├── fx/
│   ├── palettes/              palette-swap lookup rows
│   ├── fonts/                 BreeSerif-Regular.ttf, SourceSans3[wght].ttf, OFL.txt, *.tres variations
│   └── ui/                    ui_* textures (few — most UI is StyleBoxFlat)
├── shaders/                   palette_swap.gdshader, flash_hit.gdshader
├── ui/
│   ├── theme/                 main_theme.tres
│   └── screens/               main_menu.tscn, inventory.tscn …
└── scenes/                    world/, characters/, buildings/
art_src/                       (outside res:// or with a .gdignore) SVG / .afdesign masters
```

Put a `.gdignore` in `art_src/` if it lives inside the project folder so Godot does not import
masters.

---

## 4. Dimensions

| Asset | Size (1×) | Notes |
|-------|-----------|-------|
| Terrain tile | 48 × 48 | atlas per terrain set, e.g. 12 × 4 tiles = 576 × 192 |
| Character cell | 96 × 96 | all frames of all animations of one character share it |
| Big creature cell | 144 × 144 / 192 × 192 | |
| Small props | 48 × 48 or 48 × 96 | barrel, crate, anvil |
| Trees | 144 × 144 (3 × 3 tiles) small, 192 × 192 large | canopy may overhang the cell's tile footprint |
| Buildings | whole tiles: cottage 4 × 4 (192 × 192), smithy 6 × 5 (288 × 240), inn 9 × 7 L-shape (432 × 336) | roof and walls as separate sprites |
| Inventory icon | 64 × 64 (1×), 128 × 128 (HiDPI) | 6 px safe margin at 64 |
| Item on ground | 32 × 32 | downscaled icon, add flat ground shadow |
| UI reference | 1920 × 1080 mock-ups | built on a 1280 × 720 base; UI textures exported at 1.5× (1080p) or 2× (1440p+) |
| Masters | 512 × 512 sprite masters (as the examples) | example 512 px characters → 96 px cell = scale 0.1875 |

Optional HiDPI set: everything ×2 (96 px tile, 192 px cells) from the same SVG, in parallel
`*_2x/` folders, switched at load time for 1440p/4K.

---

## 5. Orientation, mirroring and scale

- **Straight top-down.** Camera looks straight down. No visible south walls on characters; buildings may show a thin wall strip below the roof for readability, consistently on all buildings.
- **Default facing: south.** Idle and portrait-less dialogue use `_s`.
- **4 directions:** S, N, W authored; E = W with `flip_h = true`.
- **Mirroring caveats:**
  - Asymmetric props/equipment swap sides (smith's single left pauldron, right-hand hammer,
    left-hip tongs). Author `_e` for the blacksmith; accept the swap for villagers.
  - The hard shadow is baked bottom-right; mirroring puts it bottom-left. For hero characters,
    keep shadow shapes in a `_shadow` layer per part and use a dedicated E shadow set; for
    small background NPCs the error is acceptable.
  - Text, signs and emblems (inn sign, anvil emblem) must never be mirrored — keep them as
    separate un-flipped child sprites.
- **Scale consistency:** smith's shoulders ≈ 1 tile (48 px); adventurer ≈ 0.85 tile; door ≈ 1 tile;
  barrel ≈ 0.75 tile. Never scale sprites in the editor to "fix" size — fix the export.
  Keep `scale_reference.png` (smith, adventurer, villager, barrel, door, tree on a 48 px grid).

---

## 6. Transparency

- PNG RGBA, straight (non-premultiplied) alpha, sRGB.
- Anti-aliased edges only on the silhouette; **no semi-transparent pixels inside shapes**
  except deliberate ones (ground shadow at 22 % `#2e2a35`).
- Ground shadows: baked into character/prop sprites *or* a shared `fx_shadow_ellipse.png`
  child sprite (recommended for characters — it stays put while the body animates).
- Godot import: **Fix Alpha Border = on** to avoid dark fringes under Linear filtering.
- Scenes/backgrounds (menu, town overview mock-ups) are opaque.

---

## 7. Pivots & anchoring (Y-sort)

| Asset | Pivot / origin | Godot setup |
|-------|----------------|-------------|
| Characters | **feet centre**, bottom-centre of the body inside the 96 px cell (x = 48, y ≈ 72) | `Sprite2D.offset = (0, -24)` with `centered = true`, so the node origin is at the feet |
| Trees | **trunk base** | origin at trunk; canopy drawn above with offset; Y-sort by trunk |
| Props | footprint bottom-centre | |
| Buildings | footprint bottom-centre (south wall line) | roof as child; hide/fade roof on entry |
| Tiles | top-left (TileMap default) | |
| Icons | centred | `TextureRect` stretch mode *keep centred* |
| FX | centre of effect | |

Enable **Y Sort Enabled** on the world root and on each container node; characters, props,
trees and buildings must be siblings under Y-sorted parents so the origin decides draw order.

---

## 8. Godot 4.x import recommendations

| Setting | Value | Reason |
|---------|-------|--------|
| Texture filter (Project Settings → Rendering → Textures → Default Texture Filter) | **Linear** | anti-aliased vector shapes; Nearest would make the 1.5× upscale jagged |
| Mipmaps | **Off** | 2D at fixed zoom; turn on only for assets seen at camera zoom < 0.5 (world map) |
| Compress mode | **Lossless** | flat colours band and smear under VRAM compression; also keeps the palette-swap shader exact |
| Fix Alpha Border | On | |
| Premultiplied alpha | Off | |
| Atlas packing | Godot "Import As: AtlasTexture" for icon sets, or pack with TexturePacker into `*_atlas.png`; one atlas per character/biome | fewer draw calls, palette rows stay separate |
| Stretch mode | **`canvas_items`**, aspect **`expand`**, base 1280 × 720 | UI and text render at native resolution (crisp fonts); flat art upscales cleanly with Linear. Use `viewport` only if you switch to pixel art. |
| Snap 2D transforms / vertices to pixel | Off | not pixel art; avoids jitter in smooth camera movement |

### Scenes & resources
- **SpriteFrames** (`*_frames.tres`) per character for `AnimatedSprite2D` villagers; hero
  characters use a cut-out rig with `AnimationPlayer`. Animation names: `walk_s`, `walk_n`,
  `walk_w`, `idle_s`, … (E via `flip_h`).
- **TileSet / TileMapLayer:** one `TileSet` with 48 px tiles; terrain sets for grass, road,
  stone, water (*Match Corners and Sides*); physics and navigation layers on the same TileSet;
  separate `TileMapLayer` nodes for ground, decor, and collision-only.
- **Theme resource** `res://ui/theme/main_theme.tres`: default font Source Sans 3 (FontVariation
  wght 400), type variations `TitleLabel` (Bree Serif MSDF, shadow offset 3 px, `#2e2a35`),
  `HeadingLabel` (Bree Serif), `StatLabel` (Source Sans 3 600 + `tnum`); buttons as
  `StyleBoxFlat` (radius 6–8, `#3a3542` normal, `#f2a33a` pressed, `#f7d27a` hover border).
- **Lighting:** world under a `CanvasModulate`; `PointLight2D` for forge/lanterns; UI on a
  `CanvasLayer` so it is not tinted.
- **Palette swap:** `palette_swap.gdshader` on a shared `ShaderMaterial`; per-instance palette
  row via `instance uniform` or a small per-NPC material duplicate.
