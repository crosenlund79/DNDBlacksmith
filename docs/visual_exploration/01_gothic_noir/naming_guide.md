# Naming & Asset Guide · 01 Gothic Noir Top-Down — "Embers of the Forgotten"

Conventions for file names, folders, dimensions, orientation, pivots and Godot
import settings for this direction. All numbers are tuned for the painted-ink
look (thick outlines, hatching, grain) and are consistent with `README.md` and
`prompts.md`.

---

## 1. File naming

**Pattern:** `<prefix>_<subject>[_<variant>][_<action>][_<dir>][_<frame>].png`

- `snake_case`, lowercase ASCII, no spaces; numbers zero-padded to 2 digits.
- Order is always: subject → variant → action → direction → frame.
- Source/master files use the same name with a `_src` suffix and live outside
  `res://` (see §2).

| Prefix | Category | Examples |
|---|---|---|
| `chr_` | Characters & creatures | `chr_blacksmith_walk_s_04.png`, `chr_adventurer_idle_e_01.png`, `chr_villager_b_walk_n_03.png` |
| `por_` | Dialogue portraits | `por_blacksmith_angry.png`, `por_innkeeper_neutral.png` |
| `eqp_` | Equipment icons & equip layers | `eqp_sword_longsword_rune.png`, `eqp_armor_plate_anvil.png`, `eqp_layer_pauldron_steel_walk_s_04.png` |
| `itm_` | Materials, consumables, misc items | `itm_ore_iron.png`, `itm_potion_red.png` |
| `env_` | Nature, terrain, props | `env_tree_oak_a.png`, `env_barrel_01.png`, `env_tile_grass_dark_03.png` |
| `bld_` | Buildings & building parts | `bld_smithy_roof.png`, `bld_inn_tipsy_wyvern.png`, `bld_chapel.png` |
| `ui_` | Interface | `ui_button_normal.png`, `ui_button_hover.png`, `ui_panel_leather_9slice.png`, `ui_logo_title.png` |
| `fx_` | Effects, particles, light textures | `fx_ember_01.png`, `fx_spark_burst_03.png`, `fx_light_forge_radial.png`, `fx_fog_layer_a.png` |
| `nrm` suffix | Normal maps | `chr_blacksmith_walk_s_04_n.png`, `bld_smithy_roof_n.png` |

**Direction suffixes:** `s`, `n`, `e`, `w` (4-dir) and `se`, `sw`, `ne`, `nw`
(8-dir). Default/unsuffixed = `s`.

**Action names:** `idle`, `walk`, `run`, `hammer`, `carry`, `interact`, `talk`,
`quench`, `hit`, `death`.

**Sheets:** `chr_blacksmith_walk_sheet.png` (+ `.json` if exported by
Aseprite/TexturePacker). Rows = directions in order S, W, E, N (then SW, SE,
NW, NE); columns = frames.

---

## 2. Folder layout

```text
res://
├─ art/
│  ├─ characters/
│  │  ├─ blacksmith/          chr_blacksmith_*.png, *_n.png, blacksmith_frames.tres
│  │  ├─ adventurers/
│  │  ├─ villagers/
│  │  └─ creatures/
│  ├─ portraits/
│  ├─ items/
│  │  ├─ weapons/             eqp_sword_*.png …
│  │  ├─ armor/
│  │  └─ materials/
│  ├─ environment/
│  │  ├─ tiles/               env_tile_*.png, tileset_village.tres
│  │  ├─ nature/              env_tree_*, env_bush_*, env_rock_*
│  │  └─ props/
│  ├─ buildings/
│  │  ├─ smithy/
│  │  ├─ inn/
│  │  └─ village/
│  └─ fx/
│     ├─ particles/
│     ├─ lights/              fx_light_*.png (PointLight2D textures)
│     └─ shaders/             outline.gdshader, grain_vignette.gdshader, fog.gdshader
├─ ui/
│  ├─ fonts/                  GrenzeGotisch-*.ttf, Grenze-*.ttf, AlegreyaSans-*.ttf, OFL.txt
│  ├─ themes/                 theme_gothic.tres, font_stats_tnum.tres
│  └─ textures/               ui_*.png
└─ scenes/ …
```

Masters (512 px icons, 2× character sheets, layered `.kra`/`.psd`/`.aseprite`)
live in a sibling `art_src/` folder **outside** `res://` (or in a folder with a
`.gdignore` file) so Godot does not import them.

---

## 3. Dimensions

**World grid unit: 32 px** (logic/collision grid). **Visual tile: 64 px**
(2×2 grid units) — thick 5-px-class ink and hatching need room; smaller tiles
turn the hatching into noise.

All in-game sizes below are **1× delivery sizes at the 1920×1080 reference
resolution**. Draw/generate masters at **2×** (or 4× for icons) and downscale.

| Asset class | Master (source) | In-game delivery | Notes |
|---|---|---|---|
| Characters (sprite canvas) | 256×256 (2×) | **128×128** | Blacksmith shoulders ≈ 80 px wide; footprint ≈ 46 px (≈1.5 grid units) |
| Large creatures | 512×512 | 256×256 | Multiples of 64 |
| Equip layers | same as character | 128×128 | Pixel-aligned to body frames |
| Dialogue portraits | 1024×1024 | 512×512 | 3/4 bust, same ink rules |
| Item icons | **512×512** | **128×128** (and 64×64 for compact lists) | Downscale with Lanczos; re-check outline ≥ 2 px after downscale |
| Terrain tiles | 128×128 | **64×64** | Seamless; 1–2 px overlap allowed for ink edges via autotile borders |
| Trees | 512×512 | 192×192 or 256×256 | Canopy 3–4 tiles across |
| Buildings | 2× | multiples of 64 (e.g. cottage 192×192, smithy 320×256, inn 448×384) | Footprint snaps to the 32 px grid |
| Props (barrel, crate, anvil) | 2× | 32–64 px | Barrel ≈ 32×32, anvil ≈ 48×32 |
| UI screens | 3840×2160 | 1920×1080 reference | 9-slice panels at 2× sources |
| UI buttons | 2× | 320×64 | Four state textures |
| Light textures | 512×512 | 256×256 | Soft radial, greyscale |

Outline weights at delivery size: characters 2–3 px inner + 2 px outer;
icons at 128 px: ~1.5 px inner + 1 px outer (from the 5 + 4 px master at 512).
If a downscale drops the outer border below 1 px, use the outline shader
instead (see §8).

---

## 4. Sprite orientation

- **Straight top-down** for every world asset: tops of heads, shoulders, roofs,
  canopies. No visible building walls except a thin eave edge; no faces.
- **Default facing: south** (toward the bottom of the screen). An asset with no
  direction suffix faces south.
- **4 directions** (S, N, E, W) for all characters; **8 directions** optionally
  for the blacksmith and the adventurer companion.
- **E/W mirroring caveats:** the blacksmith's pauldron (left shoulder), hammer
  (right hand) and tongs (left hip) and the adventurer's sword (right) and
  dagger (left hip) are asymmetric. Flipping W from E would swap sides.
  - Protagonist and named characters: draw E and W separately, **or** keep
    asymmetric props on separate layers and re-attach them after `flip_h`.
  - Background villagers without asymmetric gear: mirroring is fine.
- Icons: weapons at 45°, tip top-right; armour in front view; materials
  top-down or 3/4 as a small still life — consistent per category.
- Light stays **top-left in every direction**: do not rotate shading when
  drawing N/E/W frames.

---

## 5. Scale consistency

| Reference | Size at 1× | In grid units (32 px) |
|---|---|---|
| Blacksmith footprint (boots/belly) | ~46 px wide | ≈ 1.5 |
| Blacksmith shoulder span incl. pauldron | ~80 px | 2.5 |
| Adventurer shoulder span | ~64 px | 2 |
| Villager adult | ~56 px | 1.75 |
| Child | ~40 px | 1.25 |
| Single door width | 64 px | 2 |
| Double door / inn entrance / forge yard gate | 96–128 px | 3–4 |
| Anvil | 48×32 px | 1.5 × 1 |
| Cart | 96×64 px | 3 × 2 |
| Cottage roof | 192×192 px | 6 × 6 |

Keep a `chr_scale_reference_sheet.png` (blacksmith, adventurer, villager,
child, door, barrel, anvil on a 32/64 px grid) in `art_src/` and check every
new asset against it.

---

## 6. Transparency

- PNG-32, **straight (non-premultiplied) alpha**, sRGB.
- No matte halos: after background removal, the outer ink border must touch
  transparent pixels directly. Check on black and magenta backgrounds.
- Edge pixels of the ink border should be ink colour (`#0d0b0a`) with partial
  alpha, never light or green-tinted.
- **Padding:** ≥ 4 px at delivery size (≥ 24 px at 512 masters) so outline
  shaders and filtering do not clip; 2 px extrude between atlas regions.
- Ground shadows: preferably **not baked** into characters (separate
  `fx_shadow_ellipse.png` under the sprite) so they can follow lights. If baked,
  keep them black at ~45 % alpha.
- Only compositions (menu backgrounds, key art) are opaque.

---

## 7. Pivot & anchoring

| Asset | Pivot / anchor | Godot setup |
|---|---|---|
| Characters | Ground-contact centre (between the feet, under the belly) — about x = 64, y = 88 on a 128 canvas | `Sprite2D.offset = (0, -24)` with `centered = true`, node origin at feet |
| Equip layers | Same pivot as body | Children of the body sprite, zero offset |
| Trees | Trunk base (not canopy centre) | Origin at trunk base; canopy on a separate higher Y-sort layer or `z_index` +1 if players walk under it |
| Buildings | **Bottom-centre of the footprint** (front wall line) | Origin at bottom-centre for Y-sort; roof as separate sprite for fade-when-behind |
| Props | Bottom-centre of contact area | — |
| Icons | Exact centre | `TextureRect` stretch *keep aspect centred* |
| Light textures | Centre | `PointLight2D` at the fire's centre |

---

## 8. Godot import & project recommendations

| Setting | Recommendation for this style |
|---|---|
| Texture filter | **Linear** (painted/inked, not pixel art). Set project default `rendering/textures/canvas_textures/default_texture_filter = Linear` |
| Mipmaps | **Off** for 2D sprites and UI; on only for textures shown far below 50 % scale (e.g. world-map zoom-out) |
| Compression | **Lossless** for characters, icons, UI and anything with ink lines (VRAM compression smears hatching and grain). **VRAM Compressed** acceptable for large opaque backgrounds, fog layers and light textures |
| Fix alpha border | On (avoids dark/light fringes under Linear filtering) |
| Premultiplied alpha | Off at import; use `CanvasItemMaterial` blend *Add* for embers/fire |
| Y-sort | `y_sort_enabled` on the world root and on `TileMapLayer`s holding props; origins as in §7 |
| Lighting | `CanvasModulate` for ambient (night ≈ `#3a4050`), `PointLight2D` for forge (`#ff8a2a`, energy 1.2–1.6, flicker), inn and lanterns (`#ffd27a`), `LightOccluder2D` on building walls |
| Normal maps | Combine diffuse + `_n` normal map in a `CanvasTexture` and assign it to the sprite's texture; set `normal_map_texture` per frame via `SpriteFrames` of `CanvasTexture`s |
| Outline | Outer silhouette border via `outline.gdshader` (canvas_item, 1–2 px at 1×, colour `#0d0b0a`); also used for hover/selection in `#ffd27a` |
| Grain & vignette | One full-screen `ColorRect` with `grain_vignette.gdshader` on a top `CanvasLayer`; do **not** bake grain into sprites as well |
| Animation | `AnimatedSprite2D` + `SpriteFrames` (`blacksmith_frames.tres`) with animation names `walk_s`, `walk_e` …; use `AtlasTexture` regions from packed sheets |
| Atlases | Pack per character / per biome; max 4096×4096; 2 px extrude |
| TileSet | Tile size 64×64 (visual), physics/navigation on the 32 px grid via half-tile shapes |
| Stretch | `display/window/stretch/mode = canvas_items`, `aspect = expand`, base size 1920×1080; 2× sources keep text and ink crisp on 1440p/4K |
| UI fonts | One `Theme` resource `theme_gothic.tres`: Grenze Gotisch (MSDF) for titles, Grenze for headings/buttons, Alegreya Sans for body, `FontVariation` `font_stats_tnum.tres` (Alegreya Sans Bold, `opentype_features` `tnum=1`, `lnum=1`) for numbers |
| Rarity colours | Stored as named colours in the theme / a `Rarity` constants script: Common `#d8d4cc`, Magic `#7b93ff`, Rare `#f2d65a`, Legendary `#ff8a30`, Unique `#c9a35a`, Set `#45d46e` |

---

## 9. Quick checklist per delivered asset

- [ ] Name follows §1 (prefix, snake_case, direction & frame suffix)
- [ ] Correct folder (§2); master in `art_src/`
- [ ] Delivery size per §3; outline still ≥ 1 px outer at 1×
- [ ] Facing south / correct direction; light still top-left (§4)
- [ ] Matches scale reference sheet (§5)
- [ ] Straight alpha, no halos, padding (§6)
- [ ] Pivot documented / consistent (§7)
- [ ] Import preset applied: Linear, mipmaps off, Lossless (§8)
- [ ] Normal map `_n` present if the asset sits within forge/lantern light range
