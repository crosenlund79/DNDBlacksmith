# Naming & Asset Guide — 08 Ink & Parchment, Gothic-Tempered · "The Smith's Chronicle"

Conventions for files, sizes, pivots and Godot 4.x import for this direction. **Everything in
[`../04_ink_parchment/naming_guide.md`](../04_ink_parchment/naming_guide.md) applies unchanged**
unless this file says otherwise; the sections below restate the essentials and list what the Gothic
seasoning adds. See [README](README.md) for the style and the dial values, and
[prompts.md](prompts.md) for generation.

The short version of the difference: **same colour art as 04, plus a few companion textures** —
soot/wear overlays, light textures for `PointLight2D`, and emissive masks for legendary and magical
items. Night, dusk and interior moods come from modulate and lights, **never from separate art**.

---

## 1. File naming

* `snake_case`, lowercase ASCII, no spaces, no dates, no version numbers; British spelling
  (`armour`, `colour`).
* Pattern (as 04): `<prefix>_<subject>[_<variant>][_<action>][_<dir>][_<frame>][_<map>].png`
* Frames two digits from `01`; directions `s`, `n`, `e`, `w`.
* Masters live under `_source/` with `_master`; only target-size exports go into `res://assets/`.

| Prefix | Category | Examples |
|---|---|---|
| `chr_` | Characters, NPCs, creatures | `chr_blacksmith_walk_s_04.png`, `chr_adventurer_idle_e_01.png` |
| `eqp_` | Items, weapons, armour | `eqp_sword_longsword_runed.png`, `eqp_armour_plate_anvil.png` |
| `env_` | Terrain, trees, props, tiles | `env_tree_oak_02.png`, `env_prop_anvil_01.png`, `env_tiles_village.png` |
| `bld_` | Buildings, roofs, interiors | `bld_smithy_roof.png`, `bld_smithy_interior.png`, `bld_inn_tipsy_wyvern.png` |
| `ui_` | Interface, ornaments | `ui_menu_ledger_bg.png`, `ui_initial_t_grenze.png`, `ui_seal_wax.png`, `ui_panel_dialogue_leather_9slice.png` |
| `fx_` | Effects, overlays, light textures | `fx_ember_02.png`, `fx_soot_overlay.png`, `fx_light_forge_radial.png` |
| `map_` | Illustrated maps | `map_town_overview.png` |

### New suffixes and names in 08

| Suffix / name | Meaning | Format | Examples |
|---|---|---|---|
| `_wear` | Per-asset wear/soot **mask** (where soot may appear), greyscale | R8 PNG, same canvas as the colour sprite | `chr_blacksmith_walk_s_04_wear.png`, `eqp_armour_plate_anvil_wear.png` |
| `_emit` | Emissive / ember **mask** for glow (legendary, magical, hot metal, fire) | RGBA, ember colour on transparency, same canvas | `eqp_sword_grimhold_emit.png`, `env_prop_forge_emit.png` |
| `fx_soot_*` | Tileable or placed soot/grime overlay textures | RGBA or R8 | `fx_soot_overlay.png` (tileable), `fx_soot_mask_smithy.png` (placed) |
| `fx_light_*` | Light textures for `PointLight2D` | R8 or RGBA, soft radial | `fx_light_forge_radial.png`, `fx_light_lantern_soft.png`, `fx_light_candle_small.png` |
| `fx_vignette_*` | Screen vignettes for danger/mystery | RGBA | `fx_vignette_ink_soot.png` |
| `fx_ember_*` | Particle sprites | RGBA, small | `fx_ember_01.png` … `fx_ember_04.png` |

**Not allowed:** `_night`, `_dusk`, `_dark` variants of colour sprites or tiles. If a night look
seems to need repainting, fix the lighting setup instead (README *Godot implementation*). Exception:
lit windows may get an `_emit` mask (`bld_inn_tipsy_wyvern_emit.png`) so they glow at night.

---

## 2. Folder layout (`res://`)

04's layout, with three additions (marked `+`):

```text
res://
├── assets/
│   ├── characters/            chr_*.png, chr_*_wear.png, *_frames.tres
│   ├── equipment/
│   │   ├── icons/             eqp_*.png (128x128), eqp_*_emit.png
│   │   └── held/
│   ├── environment/           trees/, props/, tilesets/
│   ├── buildings/             bld_*.png, bld_*_emit.png (lit windows, forge mouth)
│   ├── maps/
│   ├── ui/                    ornaments/, menu/, theme/chronicle_theme.tres
│   ├── fx/
│   │   ├── overlays/          fx_paper_grain.png, fx_hatch_overlay.png, + fx_soot_overlay.png, fx_soot_mask_*.png
│   │ + ├── lights/            fx_light_*.png (PointLight2D textures)
│   │ + └── particles/         fx_ember_*.png, fx_spark_*.png
│   └── fonts/                 IM Fell English SC, IM Fell English, EB Garamond, + Grenze Gotisch; OFL.txt each
├── shaders/                   paper_overlay, line_boil, night_hatch, actor_outline (04)
│                              + soot_overlay.gdshader, emissive_add.gdshader, dusk_grade.gdshader
└── _source/                   (excluded from export) masters, .kra/.psd, generation sidecars
```

---

## 3. Dimensions

**Reference resolution 1920×1080**, tile **64×64 px** — as 04.

| Asset type | Master | In-game canvas | Notes |
|---|---|---|---|
| Characters | 512×512 | **128×128** | Body ≈ 64–80 px wide |
| Large creatures | 1024×1024 | 256×256 | |
| Item icons | 512×512 | **128×128** | 64 px in slots, 128 px in tooltips |
| Held items / world drops | 512×512 | 64×64 or 128×128 | |
| Trees | 512×512 | 192×192 or 256×256 | |
| Props | 256×256 | 64×64 – 128×128 | |
| Buildings | 4× target | **Multiples of 64** | Smithy ≈ 256×192, inn ≈ 384×256 |
| Tilesets | 4× target | 64×64 per tile | |
| UI screens / maps | 1920×1080 (or 3840×2160) | 1920×1080 | |
| Ornaments; Grenze initials | vector or 4× | as used | Initial ≈ 96–128 px (menu up to ~240 px) |
| Paper overlay | — | 1024×1024, tileable | as 04 |
| **`_wear` / `_emit` masks** | same as colour master | **same canvas as the colour sprite** | must align pixel-for-pixel; same pivot |
| **Soot overlay (tileable)** | — | 1024×1024, tileable | low-frequency; 128–256 px blotch scale |
| **Placed soot masks** | — | power of two, ≤ 1024 | e.g. smithy yard 512×512 |
| **Light textures** | — | 256×256 (lanterns, candles), 512×512 (forge) | soft radial falloff, no hard edge |
| **Ember particles** | — | 8×8 – 16×16 | |

### Line weight for target size

As 04, with the hybrid's heavier line. Minimums at in-game size:

| Element (in-game size) | 04 | 08 minimum | 08 recommended |
|---|---|---|---|
| Actor outer contour (incl. silhouette outline) | 2 px | 2.5 px | 3 px |
| Environment outline | 1.5 px | 2 px | 2 px |
| Interior detail | 1 px | 1 px | 1.5 px |
| Hatch lines | 1 px, pitch ≥ 3 px | 1 px, pitch ≥ 3 px | same; core shadows may use pitch 2.5 px |
| Icon outline (128 px) | 1.5 px | 2 px | 2–2.5 px |

At a 512 px master meant for 4× reduction: actor contours ≈ 10–12 px, hatching ≈ 4 px line / 12 px
pitch. Soot texture must be low-frequency enough to survive the reduction (blotches ≥ 16 px at
512 px); fine soot speckle turns to grey noise at 128 px.

---

## 4. Sprite orientation

As 04: **straight top-down**, default facing **south**, **4 directions** (S, N, E, W). Do not
mirror asymmetric characters (pauldron, eyepatch, hammer, tongs, and also the asymmetric soot on the
smith's forearms would swap). Mirror symmetric NPCs/props only if hatching comes from the screen-space
shader. `_wear` and `_emit` masks follow their sprite's direction and frame exactly.

Icons: weapons 45° diagonal tip top-right; armour front view; consumables upright.

---

## 5. Scale consistency

As 04: 1 tile = 64 px; blacksmith shoulders ≈ 80 px at 128 px canvas, adventurer ≈ 68 px; doors
64 px, barrels ≈ 40 px, anvil ≈ 56×32 px; tree canopies 160–240 px. Keep
`_source/ref_scale_sheet.png` and add the 04 equivalents to it for the squint test. Never fix size
errors with node `scale`.

Light radii are part of scale: forge light ≈ 4–5 tiles, inn door ≈ 3 tiles, lantern ≈ 2 tiles,
candle ≈ 1 tile.

---

## 6. Transparency

* PNG, RGBA, **straight (non-premultiplied) alpha**; anti-aliased ink with edge pixels in ink colour
  `#24170e` (not blended toward white) — matters more here, because sprites appear on darker
  modulated ground at night.
* **Not baked into colour sprites:** parchment, paper grain, vignette (as 04) **and** soot overlay,
  glow, rim-light from dynamic lights, night tint. Exceptions: `map_*` and full-screen `ui_*`.
* **Baked and allowed:** the ink-and-wash drawing including deeper shadow wash, the thin 40 % ember
  rim on metal/gold/gem/fire, and *local* storytelling soot that is part of the object (scorch on the
  apron, soot on the hammer head) — keep that ≤ 5 % of the sprite; general grime goes in `_wear`.
* `_wear` masks: greyscale, white = soot allowed, black = none; no alpha needed (R8).
* `_emit` masks: ember colour (`#e0782a`, cores `#ffc070`) on transparency; drawn **inside** the
  sprite silhouette, at most 2–3 px beyond it. The soft halo is generated in-engine.
* Light textures: white-to-transparent (or white-to-black R8) radial, no colour (colour comes from
  `PointLight2D.color`).
* Trim nothing at export; masks and sprites must share canvas and pivot.

---

## 7. Pivot & anchoring

| Asset | Pivot | Godot setup |
|---|---|---|
| Characters | Feet centre (≈ y 0.80 of canvas) | `centered = true`, `offset.y = -(0.30 × h)`; Y-sort on origin |
| Trees | Trunk base | Origin at trunk base |
| Buildings, props | Bottom-centre of footprint | Origin at south wall centre |
| Icons | Centre | `centered = true` |
| `_wear` / `_emit` masks | **Identical to their sprite** | Same node (shader sampler) or a child `Sprite2D` with identical offset |
| Light textures | Centre | `PointLight2D` at the light source: forge mouth, door, lantern flame |
| Ember emitters | Emitter point | `GPUParticles2D` at the forge mouth / torch |
| Overlays | Top-left (tileable) or world position (placed masks) | `CanvasLayer` or world-space `Sprite2D` |

---

## 8. Godot 4.x import recommendations

**Textures** — as 04: filter **Linear**, mipmaps off at 1:1 (on for zoomed-out maps), compression
**Lossless**, `fix_alpha_border = true`, `premult_alpha = false`. Additionally:

* `_wear` masks, `fx_soot_*`, `fx_light_*`: may use **Lossy** (WebP ≥ 0.85) or VRAM-compressed
  formats — they are soft and low-frequency. Import R8 masks with `compress/mode = Lossless` and
  `process/channel_pack` left default; Godot keeps single-channel PNGs compact.
* `_emit` masks: **Lossless** (they carry hard ember edges on blades and gems).
* Tileable overlays: set `repeat = Enabled` on the `CanvasItem` (`texture_repeat`).

**World rendering** (04's setup + Gothic layer)

| Layer | Node / resource | Values |
|---|---|---|
| Ambient (time of day) | `CanvasModulate` driven by `AnimationPlayer` | day `#ffffff`, dusk ≈ `#d8c8b0`, night ≈ `#6c6a80`, forge interior ≈ `#8a7a6a` |
| Dusk grade | `dusk_grade.gdshader` on a full-screen `ColorRect`, multiply | diagonal 6 % → 15 %, toward bottom-right |
| Night hatch | 04's `night_hatch.gdshader` | max density +25 % vs 04; masked inside light radius |
| Lights | `PointLight2D`, `blend_mode = Add`, textures `fx_light_*` | forge `#e0782a` energy 1.0–1.4 ±10 % flicker; inn/lanterns `#ffc070` 0.5–0.8; candles 0.3–0.5; **≤ 3 strong per screen** |
| Soot | `soot_overlay.gdshader`: multiplies `fx_soot_overlay.png` (world-anchored) by `_wear` masks / placed `fx_soot_mask_*` | colour `#1a120c`, global `soot_strength` 0–1 (day ≈ 0.6, interiors ≈ 0.8) |
| Emissive | `emissive_add.gdshader` or child `Sprite2D` with `CanvasItemMaterial.blend_mode = Add` using `_emit` | legendary pulse 0.6–1.0 over ~2 s; unaffected by `CanvasModulate` (`light_mode = Unshaded`) |
| Embers | `GPUParticles2D`, additive, `fx_ember_*` | ≤ 1 emitter per light source |
| Vignette | full-screen `ColorRect`, radial `#3a2410` | 0 % centre → ≤ 50 % corners; danger up to 70 % |
| Paper, line boil, outline | 04 shaders | `actor_outline` may supply the 1.2 px (master) silhouette at target size |

* **No normal maps and no `LightOccluder2D` by default** (01's pipeline). Add them only for a specific
  set piece; they push the look and cost toward 01.
* Characters: `AnimatedSprite2D` + `SpriteFrames`; if a `_wear` mask is used per frame, feed it
  through a shader parameter updated from the frame index, or pack colour + wear frames into matching
  sprite sheets (`chr_blacksmith_walk_s_sheet.png` + `chr_blacksmith_walk_s_sheet_wear.png`).

**Window & UI** — as 04 (1920×1080, `canvas_items`, `expand`; test 1280×720 and 2560×1440). Theme
`res://assets/ui/theme/chronicle_theme.tres` with 04's font types, plus:

* `InitialLabel`: Grenze Gotisch 800, MSDF on, hinting None, colour `#8e2a16`; initials only.
* Dark `StyleBoxFlat` for tooltips and dialogue (`#2a1c12` → `#140e08`, border `#6e4a2a` 1–2 px),
  speaker name `#ff9a48`; rarity colours per README tables (parchment and dark sets).
* Panels: parchment 9-slice with **heavier** ink border (3 px at 1080p vs 2 px in 04).
* Hover/focus: rubric border + italic + faint ember underlay (`#e0782a` at ~15 %); the only UI use
  of ember besides the speaker name and Legendary text.

---

## 9. Consistency notes

* Each 08 asset should have a 04 counterpart in the review sheet; reject it if it fails the README
  squint test (Gothic shift > 0.25 by day).
* One soot overlay texture and one set of light textures for the whole game; per-asset differences
  live in `_wear` masks and light energy, not in new textures.
* Ember appears only on the README reserved list; `_emit` masks exist only for those items.
* Night/dusk/interior screenshots for review are taken in-engine, never painted.
* Keep `OFL.txt` for all four families (IM Fell English SC, IM Fell English, EB Garamond, Grenze
  Gotisch) in `res://assets/fonts/` and list them in the credits.
