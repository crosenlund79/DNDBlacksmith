# 03 — Bold Readable Adventure Sim · Naming & Import Guide

Conventions for producing and importing assets in the "Forged Fortunes" direction into Godot 4.x. Numbers here are tuned for this style's outline weights (see [`README.md`](README.md)) and the prompts in [`prompts.md`](prompts.md).

---

## Filename conventions

- **snake_case**, lowercase ASCII, no spaces, no dates or "final" in names (use git history).
- Pattern: `<prefix>_<subject>[_<variant>][_<action>][_<direction>][_<frame>].png`
- Frames are **two-digit, 1-based** (`_01`, `_02` …). Directions use compass letters.

| Prefix | Category | Examples |
|--------|----------|----------|
| `chr_` | Characters & creatures | `chr_blacksmith_idle_s_01.png`, `chr_blacksmith_walk_s_04.png`, `chr_adventurer_ranger_attack_ne_03.png` |
| `eqp_` | Equipment & items (icons and worn layers) | `eqp_sword_longsword_icon.png`, `eqp_sword_longsword_mithril_icon.png`, `eqp_armor_breastplate_worn_s.png` |
| `env_` | Terrain, nature, tiles | `env_tree_oak_01.png`, `env_tiles_village_ground.png`, `env_bush_02.png` |
| `bld_` | Buildings & large structures | `bld_smithy.png`, `bld_inn_tipsy_wyvern.png`, `bld_chapel.png` |
| `prp_` | Small props (optional split from `env_`) | `prp_barrel_01.png`, `prp_anvil.png`, `prp_quench_trough.png` |
| `ui_` | Interface | `ui_button_big_normal.png`, `ui_button_big_hover.png`, `ui_panel_navy_9slice.png`, `ui_icon_gold.svg` |
| `fx_` | Effects & particles | `fx_spark_01.png`, `fx_forge_glow.png`, `fx_smoke_puff_03.png` |
| `ref_` | Reference sheets (not shipped) | `ref_scale_sheet.png`, `ref_palette.png` |

**Suffixes**

| Suffix | Meaning |
|--------|---------|
| `_s _sw _w _nw _n _ne _e _se` | Facing direction (south = default) |
| `_01 … _nn` | Frame number |
| `_icon` | Inventory icon variant of an item |
| `_worn` | Layer drawn on a character |
| `_shadow` | Separate ground/cast shadow sprite |
| `_nooutline` | Version without outer contour (for shader outlines) |
| `_sheet` | Packed sprite sheet; frames in reading order |
| `_iron _steel _mithril _gold` | Material tier (or generate via palette shader — see README) |
| `_9slice` | NinePatchRect texture |

Source files share the name with a different extension: `chr_blacksmith.svg` / `.kra` / `.af` → exports `chr_blacksmith_*.png`.

---

## `res://` folder layout

```text
res://
├─ art/
│  ├─ characters/
│  │  ├─ blacksmith/        chr_blacksmith_*.png, chr_blacksmith.tres (SpriteFrames)
│  │  ├─ adventurers/
│  │  └─ villagers/
│  ├─ equipment/
│  │  ├─ icons/             eqp_*_icon.png (128 px)
│  │  └─ worn/              eqp_*_worn_<dir>.png
│  ├─ environment/
│  │  ├─ tiles/             env_tiles_*.png + *.tres (TileSet)
│  │  ├─ nature/            env_tree_*, env_bush_*
│  │  └─ props/             prp_*
│  ├─ buildings/            bld_*
│  ├─ fx/                   fx_*
│  └─ palettes/             palette lookup textures for swap shader
├─ ui/
│  ├─ theme/                forged_fortunes_theme.tres, type variations
│  ├─ textures/             ui_*.png / ui_*.svg
│  └─ fonts/                CinzelDecorative-Black.ttf, Signika[wght].ttf, *.tres FontVariation
├─ shaders/                 outline.gdshader, palette_swap.gdshader
└─ source_art/              (excluded from export) 512 masters, SVG, layered files
```

Mark `source_art/` as excluded in the export preset (or keep it outside the project and use `.gdignore`).

---

## Suggested dimensions

Base grid: **64 px tile** at 1920×1080 reference resolution (30 × ~17 tiles on screen).

| Asset | Master | In-game export | Notes |
|-------|--------|----------------|-------|
| Characters | 512×512 PNG or SVG | **128×128 canvas** (exactly 1/4) | Body ≈ 1 tile wide; 4 px master lines → 1 px; 4 px contour → 1 px. For heavier lines in game, author 6–8 px at master. |
| Large creatures | 1024×1024 | 256×256 | Keep the same 1/4 ratio |
| Inventory icons | 512×512 | **128×128** (tooltips, shop) and **96×96** (grid slots) | 96 is 3/16 — re-check outline after downscale; prefer 128 if outlines blur |
| Worn equipment layers | 512×512 | 128×128 | Same canvas & pivot as the character |
| Trees | 512×512 | 128×128 (small), 192×192 or 256×256 (large) | Canopy 2–4 tiles |
| Buildings | ×4 of target | Multiples of 64: smithy 256×256, cottage 192×192, inn 384×320, chapel 192×256 | Include cast shadow inside canvas |
| Tiles | 256×256 per tile | 64×64 | Atlas e.g. 1024×1024 |
| Props | 256×256 | 64×64 or 64×128 | Barrel, crate, anvil = 1 tile |
| FX | 256×256 | 32–128 px | Flat shapes |
| UI | 1920×1080 reference | 1:1 | Buttons 400×88, small buttons 240×64, slot frames 112×112 (96 icon + padding) |

Always scale **by integer fractions** of the master (1/2, 1/4) so outline widths stay uniform. Never mix assets exported at different ratios in one scene.

---

## Sprite orientation

- **Straight top-down** for all world sprites — no 3/4 or side views. Icons are the only exception (front view / 45° diagonal).
- Default facing is **south** (toward the bottom of the screen); `_s` frames are drawn first and are the reference.
- **8 directions recommended** for this style: readability is its selling point, and diagonal facings make movement and attacks clearly legible. Draw `s, se, e, ne, n` (5) and mirror for `sw, w, nw` where possible.
- **Mirroring caveats**: the blacksmith's single pauldron (left shoulder), hammer in right hand, tongs at left hip and the adventurer's sword hand/dagger side are asymmetric. Mirroring swaps them, so either (a) draw all 8 directions for main characters, or (b) mirror the body and re-draw only the prop layers (separate sprites/bones — easy with cut-out rigs). Villagers with symmetric clothing can be freely mirrored.
- Light stays top-left in **all** directions — do not mirror the shading. Mirror the line art and re-apply cel bands, or keep shading in a separate layer.

---

## Scale consistency

- One master scale: the blacksmith at 512 defines it. His head is the reference unit (~1/5 of the canvas width at 512 incl. 1.12× head factor).
- Doors ≈ 0.75 tile wide; adults ≈ 1 tile across the shoulders; the smith's anvil ≈ 1 tile; barrels ≈ 0.6 tile.
- Keep `ref_scale_sheet.png` up to date and compare every new asset at in-game size before import.
- Never scale sprites in the scene (`Node2D.scale`) to fix size — re-export instead; scaling changes outline thickness and breaks the style.

---

## Transparency

- PNG with **straight (non-premultiplied) alpha**, 8-bit RGBA.
- The **outer contour must lie entirely inside the canvas**. Keep padding of ≥ 24 px at 512 (≥ 6 px at 128). If you use the shader outline, add padding of at least *outline width + 2 px* so the shader has room to draw.
- No semi-transparent fringe of non-palette colours around the outline; edge pixels should blend navy into alpha.
- Ground shadows: either a separate `_shadow` sprite (navy `#1c1a2e`, 28 % opacity, preferred — allows overlap sorting) or baked into the character canvas, but be consistent per asset family.
- Effects with glow (`fx_forge_glow`) may use additive blending; author them on transparent with no outline.

---

## Pivot & anchoring

| Asset | Pivot | Godot setup |
|-------|-------|-------------|
| Characters | **Feet centre** (ground-shadow centre), ≈ (64, 86) on a 128 canvas | `Sprite2D.offset` so the node origin is at the feet; `centered = true` with negative y offset, or `centered = false` with offset (-64, -86) |
| Worn equipment | Same as character | Child of character, identical offset |
| Trees | **Trunk base** | Origin at trunk base so the canopy overlaps characters walking "behind" (north of) it |
| Buildings & props | **Footprint bottom-centre** | Origin at the bottom edge of the footprint for Y-sort |
| Icons | **Centred** | `TextureRect` with stretch mode keep-centred |
| Tiles | Top-left (TileMap default) | Texture origin per TileSet |
| FX | Centre of effect | |

---

## Godot import recommendations

| Setting | Recommendation | Why |
|---------|---------------|-----|
| Texture filter | **Linear** (Project Settings → Rendering → Textures → Default Texture Filter) | Clean vector-like art, not pixel art; Nearest makes 1 px outlines jagged |
| Mipmaps | **Off** for characters, props, UI; **on** only if the camera zooms out below 0.75× | Mipmaps blur thin outlines; enable with *Linear Mipmap* for zoomed-out map views |
| Compression | **Lossless** for characters, icons, UI, outlines | VRAM compression (BPTC/ASTC) causes artefacts on hard navy edges and flat fills |
| Compression (big backgrounds) | VRAM Compressed acceptable for large ground tiles/backdrops if memory is tight | Check for banding on flat colours |
| Fix Alpha Border | **On** | Prevents dark/light halos with Linear filtering |
| Premultiplied alpha | Off (straight alpha) | Matches authoring |
| SVG import | Consider for **UI icons and buttons**: import SVG with *SVG Scale* set to the target size (e.g. 0.25 for a 512 master → 128) | Crisp at any UI scale; keep source SVG simple (no filters — bake the outer contour as a stroke) |
| Y-sort | Enable `y_sort_enabled` on the world/`TileMapLayer` parent; set sprite origins per pivot table | Correct overlap for top-down |
| Animation | `AnimatedSprite2D` + **SpriteFrames** resource per character; frames from `_sheet.png` via **AtlasTexture** regions, or cut-out rigs with `Skeleton2D` + `AnimationPlayer` | |
| Atlases | Pack icons and props into atlases (e.g. 2048×2048) and reference with AtlasTexture | Fewer draw calls |
| Stretch mode | Project Settings → Display → Window → Stretch: **mode `canvas_items`**, aspect `expand`, base 1920×1080 | Text and outlines stay sharp at other resolutions |
| Outline shader | `shaders/outline.gdshader` on a shared `ShaderMaterial` for `_nooutline` sprites; uniforms: `outline_color = #1c1a2e`, `outline_px = 2` (at 128 px), selection colour `#ffcc33` | Constant-width outer contour, hover/selection highlight |
| Palette swap | `shaders/palette_swap.gdshader` with a lookup texture in `art/palettes/` | Equipment tiers, villager clothing |
| UI | One **Theme** resource (`forged_fortunes_theme.tres`): Signika default font 20 px, navy `StyleBoxFlat` panels (bg `#1c1a2e`, border 4 px, corner radius 12), button hover border `#ffcc33`; type variations for headings, big buttons and rarity labels | Consistency across all screens |
| Fonts | FontFile import; MSDF on for Cinzel Decorative title; FontVariation with `tnum` for numbers (see README Typography) | |

### Pre-import checklist

1. Name follows the pattern and prefix table.
2. Exported at an integer fraction of the master (1/4 default).
3. Outline and shadow inside canvas, padding respected.
4. Pivot matches the table; sheets have uniform frame size.
5. Colours belong to the palette ramps.
6. Import preset applied (Lossless, Linear, mipmaps off, Fix Alpha Border on).
