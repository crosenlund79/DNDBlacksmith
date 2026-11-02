# Naming & Asset Guide — 02 Warm Storybook Village ("The Old Anvil")

Conventions for producing and importing assets in this direction into Godot 4.x. All numbers
are tuned for soft hand-painted art on a **64 px tile grid** in a **straight top-down** view.

---

## 1. Filename conventions

- **snake_case**, lowercase ASCII, no spaces, no version numbers in shipped names (use git).
- Pattern: `<prefix>_<subject>[_<variant>][_<action>][_<direction>][_<frame>].png`
- Frame numbers are **two digits, 1-based** (`_01`…`_12`). Directions use compass letters.

| Prefix | Category | Examples |
|---|---|---|
| `chr_` | Characters, NPCs, creatures (and rig parts) | `chr_blacksmith_walk_s_04.png`, `chr_adventurer_idle_e_01.png`, `chr_blacksmith_part_beard.png` |
| `eqp_` | Equipment & item icons | `eqp_sword_rune_longsword.png`, `eqp_armor_plate_cuirass.png`, `eqp_mat_iron_ingot.png` |
| `env_` | Terrain, flora, props | `env_tree_oak_01.png`, `env_tree_oak_autumn_02.png`, `env_prop_barrel_01.png`, `env_tile_grass_a.png` |
| `bld_` | Buildings & building parts | `bld_smithy_roof.png`, `bld_inn_tipsy_wyvern_roof.png`, `bld_cottage_thatch_02.png` |
| `ui_` | UI kit, HUD, menus, fonts' companion art | `ui_panel_wood_9s.png`, `ui_button_parchment_hover.png`, `ui_icon_coin.png` |
| `fx_` | Effects, particles, light textures, shadows | `fx_spark_01.png`, `fx_smoke_puff_03.png`, `fx_glow_forge.png`, `fx_shadow_tree_m.png` |

Suffixes:

| Suffix | Meaning |
|---|---|
| `_s _n _e _w` | 4-direction facing (south default) |
| `_se _sw _ne _nw` | Extra diagonals for 8-direction sets |
| `_idle _walk _run _hammer _interact _hit` | Action |
| `_part_<name>` | Cut-out rig part (`_part_arm_upper_l`) |
| `_9s` | 9-slice UI texture |
| `_normal _hover _pressed _disabled` | UI states |
| `_nrm` | Normal maps use **`_nrm`** to avoid clashing with north (`chr_blacksmith_part_head_nrm.png`) |
| `_master` | Source masters (never in `res://`) |

Examples: `chr_blacksmith_walk_s_04.png`, `chr_blacksmith_hammer_e_03.png`,
`env_tree_oak_01.png`, `bld_smithy_roof_snow.png`, `ui_button_parchment_pressed.png`.

---

## 2. Folder layout

```text
res://
├── assets/
│   ├── characters/
│   │   ├── blacksmith/          # parts, frames, rig scene, SpriteFrames .tres
│   │   ├── adventurers/
│   │   └── villagers/
│   ├── equipment/
│   │   ├── weapons/
│   │   ├── armor/
│   │   └── materials/
│   ├── environment/
│   │   ├── tiles/               # 64 px tiles + TileSet .tres
│   │   ├── flora/
│   │   └── props/
│   ├── buildings/
│   ├── fx/
│   │   ├── particles/
│   │   ├── lights/              # PointLight2D textures
│   │   └── shadows/
│   ├── ui/
│   │   ├── kit/                 # panels, buttons, frames (9-slice)
│   │   ├── icons/
│   │   ├── menu/
│   │   └── themes/              # ui_theme_storybook.tres
│   └── fonts/
│       ├── uncial_antiqua/
│       ├── alegreya/
│       ├── nunito/
│       └── LICENSES/            # OFL.txt per family
└── scenes/ …
```

Masters (512 px icons, 256 px character parts, layered `.kra`/`.psd`) live **outside**
`res://` in `art_source/` (mirror the same structure) so Godot doesn't import them.

---

## 3. Suggested dimensions

| Asset | Final in-game size | Paint master | Notes |
|---|---|---|---|
| Tile | **64×64** | 128×128 | Ground textures painted as seamless 512×512 sheets, sliced to 64 |
| Character frame / canvas | **128×128** | 256×256 (2×) | Smith's shoulders ≈ 84 px wide; adventurer ≈ 72 px |
| Character rig part | fits 128 canvas | 256 px space | Overlap joints by 6–10 px for rotation |
| Item icon | **128×128** | 512×512 | Shown at 64 px in grids, 128 px in tooltips |
| Small prop (barrel, crate) | 64×64 | 128×128 | 1 tile footprint |
| Large prop (cart, anvil yard) | 128×128 / 192×128 | 2× | Multiples of 64 |
| Tree | 192×192 (medium), 256×256 (large) | 2× | Canopy 3–4 tiles; trunk footprint 1 tile |
| Cottage | 192×192 | 384×384 | 3×3 tiles |
| Smithy | 256×256 | 512×512 | 4×4 tiles incl. forge yard |
| Inn "The Tipsy Wyvern" | 384×320 | 2× | 6×5 tiles, L-shape |
| UI | 1920×1080 reference | same, 2× for hero art | 9-slice panels painted at 2× then downscaled |
| Key art / menu background | 1920×1080 | 3840×2160 | Opaque |

The example PNGs in this folder (512×512 sprites/icons, 1920×1080 scenes) are at **master**
size, not final game size.

---

## 4. Sprite orientation

- **Straight top-down**: the camera looks directly down. We see scalp, shoulders, beard from
  above, toes peeking out — never a face or a building wall.
- **Default facing: south** (toward the bottom of the screen). Single-direction assets (NPCs
  standing at counters, icons on the ground) face south.
- **4 directions** (S, N, E, W) for all characters; **8 directions** optional for the
  protagonist only (cost ~2× — see README).
- **Mirroring caveats:** this cast is deliberately asymmetric. The smith has a single
  pauldron on his *left* shoulder, hammer in the *right* hand, tongs at the *left* hip; the
  adventurer holds the sword right-handed, dagger on the left. Mirroring E → W would swap
  these and flip the top-left light. Therefore:
  - Characters: paint W separately **or** mirror only the body rig and re-attach asymmetric
    parts (pauldron, tools, shield) to the correct bones.
  - Always repaint/re-light form shadows after mirroring — a mirrored sprite is lit from the
    top-right.
  - Symmetric props (barrels, wells, most trees) may be mirrored for variation if the shadow
    is a separate sprite.

---

## 5. Scale consistency

- One world unit = 1 px at 1× zoom; tile = 64 px.
- Keep `art_source/scale_sheet.png` (see `prompts.md` §4): smith, adventurer, villager, door
  (1 tile wide), barrel, cottage, tree, anvil on the 64 px grid.
- Character heights from above don't matter — **shoulder width** is the scale reference:
  smith ≈ 1.3 tiles, adventurer ≈ 1.1, villager ≈ 1.0, child ≈ 0.7.
- Never scale sprites in-engine to fix a size error; re-export from the master.
- Detail floor: nothing meaningful under 3 px at final size (12 px on 512 masters).

---

## 6. Transparency

- PNG RGBA, **straight (non-premultiplied) alpha**, sRGB.
- Soft painted edges and blurred contact shadows have wide semi-transparent zones — the main
  source of **halos**:
  - Paint/generate on a background close to the asset's edge colour (warm mid-brown), not
    white; or **colour-decontaminate** after keying.
  - Bleed edge colour into fully transparent pixels (Godot's import option *Fix Alpha Border*
    = on, the default) so linear filtering doesn't pull in black/white.
  - Don't premultiply manually; let Godot handle it (`Premult Alpha` import off unless a
    shader expects it).
- **Padding:** ≥ 4 px empty border on every frame/atlas region at final size (8 px at 2×),
  more where blurred shadows extend. Atlas packing: 2 px extrusion between regions.
- Contact shadows: included in character frames (soft `#4a2e14` @ ~28 %). Long cast shadows
  (trees, buildings) as **separate** `fx_shadow_*` sprites so time of day can fade/rotate them.

---

## 7. Pivot & anchoring

| Asset | Pivot / offset | Y-sort origin |
|---|---|---|
| Characters | **Feet centre** (centre of contact shadow), ~`(64, 76)` on a 128 canvas | Same point |
| Trees | **Trunk base** (where trunk meets ground), not canopy centre | Trunk base |
| Buildings | **Footprint bottom-centre** (front wall line from above = bottom edge of roof footprint) | Footprint bottom-centre |
| Props | Bottom-centre of footprint | Same |
| Icons, UI | **Centred** | n/a |
| FX | Centred (particles), base for smoke columns | n/a or emitter base |

In Godot set `Sprite2D.centered = true` and use `offset` so the pivot lands on the node origin,
or `centered = false` with explicit `offset`; be consistent per category and document it in the
category's base scene (`character_base.tscn`, `prop_base.tscn`).

---

## 8. Godot import recommendations

| Setting | Recommendation | Why |
|---|---|---|
| Texture filter (project default) | **Linear** (`rendering/textures/canvas_textures/default_texture_filter = Linear`) | Painted art; Nearest would make soft edges jagged |
| Mipmaps | **Off** for characters, props, UI; **On** only for large backgrounds/terrain if the camera zooms out below ~0.6× (with `Linear Mipmap`) | Avoid blurring sprites; prevent shimmer when zoomed out |
| Compression | **Lossless** for characters, icons, UI, fonts' art; **VRAM Compressed** (BPTC/ASTC high quality) acceptable for large opaque backgrounds and terrain | Soft gradients and alpha band badly under lossy VRAM formats |
| Fix Alpha Border | On | Prevents dark halos on soft edges |
| Y-sort | `y_sort_enabled` on the world/entities node; TileMapLayer with Y-sort for props | Correct overlap of characters, trees, buildings |
| Time of day | `CanvasModulate` (day `#ffffff` → golden `#ffe6c4` → dusk `#c8a8c8` → night `#5a5a8a`) + `PointLight2D` for forge, lanterns, windows (`#ffb050`, blend Add) | Keeps art neutral; warmth comes from light |
| Normal maps | Optional `CanvasTexture` (`_nrm`) for protagonist and forge props only | Dynamic forge light on the smith |
| Animation | `Skeleton2D` + `Polygon2D` + `AnimationPlayer` for rigged characters; `AnimatedSprite2D` + `SpriteFrames` for frame loops and FX | See README production section |
| Atlases | Pack frames/icons into atlases; reference via `AtlasTexture` / `SpriteFrames`; one atlas per character / icon category | Fewer draw calls, consistent padding |
| Stretch | `display/window/stretch/mode = canvas_items`, aspect `expand`, base 1920×1080 | Crisp text and UI at all resolutions |
| Camera zoom | Integer-free zoom is fine (Linear filtering), but test at 0.5×, 1×, 1.5× | Painted art tolerates fractional zoom |
| UI | One `Theme` resource `ui_theme_storybook.tres`: `StyleBoxTexture` 9-slice wood/parchment panels, Nunito default font, Alegreya heading/dialogue type variations, `nunito_numbers_tnum.tres` FontVariation for stats, rarity colours as theme constants | Single source of truth for UI look |
| Fonts | `FontFile`; MSDF for Uncial Antiqua (title); raster for Alegreya/Nunito | See README → Typography |

### Quick checklist before committing an asset

- [ ] Name follows §1 and sits in the right `res://assets/...` folder
- [ ] Final size from §3; master kept in `art_source/`
- [ ] Faces south (or correct direction suffix); asymmetric parts correct after any mirroring
- [ ] Straight alpha, no halo at 1× on dark and light ground
- [ ] Pivot per §7; Y-sort verified in a test scene next to the scale sheet
- [ ] Import: Linear, mipmaps per §8, Lossless unless a large opaque background
