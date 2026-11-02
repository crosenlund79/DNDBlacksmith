# Naming & Asset Guide — Ink & Parchment / Gothic Noir 80:20 · "Ember & Ash"

Conventions for files, sizes, pivots and Godot 4.x import for the 80:20 variant. **Everything in
[`../08_ink_parchment_gothic/naming_guide.md`](../08_ink_parchment_gothic/naming_guide.md) (and through
it [`../04_ink_parchment/naming_guide.md`](../04_ink_parchment/naming_guide.md)) applies unchanged**
unless this file says otherwise. See [README](README.md) for the style, the dial and the verdict,
and [prompts.md](prompts.md) for generation.

The short version: **one set of colour art shared with 85:15, plus companion layers.** The 85:15
colour sprite is the base; the 80:20 register is that sprite plus a `_g20` overlay (extra line,
deeper shadow step, scratches/cracks/nicks), stronger `_wear` and `_emit` settings, a palette remap
and different light/grade presets. Night, dusk and interior moods still come from modulate and
lights, **never from separate art**.

---

## 1. File naming

* `snake_case`, lowercase ASCII, no spaces, no dates, no version numbers; British spelling
  (`armour`, `colour`).
* Pattern (as 04/08): `<prefix>_<subject>[_<variant>][_<action>][_<dir>][_<frame>][_<map>].png`
* Frames two digits from `01`; directions `s`, `n`, `e`, `w`.
* Masters live under `_source/` with `_master`; only target-size exports go into `res://assets/`.
* **The ratio is never part of a colour sprite's name.** `chr_blacksmith_idle_s_01.png` is the same
  file in both registers; only its companion layers and presets differ.

| Prefix | Category | Examples |
|---|---|---|
| `chr_` | Characters, NPCs | `chr_blacksmith_walk_s_04.png`, `chr_adventurer_idle_e_01.png` |
| `eqp_` | Items, weapons, armour | `eqp_sword_longsword_runed.png`, `eqp_armour_plate_anvil.png` |
| `env_` | Terrain, trees, props, tiles | `env_tree_oak_02.png`, `env_prop_well_old.png` |
| `bld_` | Buildings, roofs, interiors | `bld_smithy_roof.png`, `bld_inn_tipsy_wyvern.png` |
| `ui_` | Interface, ornaments | `ui_menu_ledger_bg.png`, `ui_initial_e_grenze.png`, `ui_corner_gilt_tl.png`, `ui_rule_gilt.png` |
| `fx_` | Effects, overlays, light textures | `fx_ember_02.png`, `fx_soot_streak_01.png`, `fx_light_rune_ring.png` |
| `map_` | Illustrated maps | `map_town_overview.png` |

### Suffixes and names (08 set + 80:20 additions marked **new**)

| Suffix / name | Meaning | Format | Examples |
|---|---|---|---|
| `_wear` | Wear/soot **mask**: where soot may appear (strength set per preset) | R8 PNG, same canvas | `chr_blacksmith_walk_s_04_wear.png` |
| `_emit` | Emissive mask: hot metal, fire, lit windows, **runes** | RGBA, ember on transparency, same canvas | `eqp_sword_longsword_runed_emit.png`, `eqp_armour_plate_anvil_emit.png` |
| **`_g20`** (new) | 80:20 overlay layer: extra outline (+0.2 px), silhouette (+0.3 px), deeper shadow step, scratches, cracks, nicks | RGBA, ink/shadow colours on transparency, same canvas; composited *normal* over the colour sprite | `chr_blacksmith_walk_s_04_g20.png`, `eqp_sword_longsword_runed_g20.png` |
| **`_pal`** (new) | Palette-remap table for a character/material set (85:15 ↔ 80:20 hues: cloak, strap, boot) | 256×2 RGBA LUT, row 0 = 85:15, row 1 = 80:20 | `chr_adventurer_pal.png` |
| `fx_soot_*` | Soot overlays and placed masks; **new:** chimney streaks and street soot | RGBA or R8 | `fx_soot_overlay.png`, `fx_soot_streak_01.png`…`_04.png`, `fx_soot_mask_streets.png` |
| `fx_light_*` | `PointLight2D` textures; **new:** window, rune ring | R8 or RGBA, soft radial | `fx_light_forge_radial.png`, `fx_light_window_soft.png`, `fx_light_rune_ring.png` |
| **`fx_rune_*`** (new) | Placed magical-illumination decals (ink + gilt rings, wards) | RGBA | `fx_rune_ring_well.png`, `fx_rune_ring_well_emit.png` |
| `fx_vignette_*` | Screen vignettes | RGBA | `fx_vignette_ink_soot.png` |
| `fx_ember_*` | Particle sprites | RGBA, small | `fx_ember_01.png` … `fx_ember_04.png` |
| **`ui_*_gilt`** (new) | Restrained gold ornaments | RGBA, vector-sourced | `ui_corner_gilt_tl.png`, `ui_frame_initial_gilt_9slice.png` |

**Not allowed:** `_night`, `_dusk`, `_dark`, `_8020`, `_80_20` or `_gothic` variants of colour
sprites or tiles. If an asset seems to need a darker repaint, fix the `_g20` layer, preset or
lighting instead. Lit windows and runes use `_emit`.

### Files in this exploration folder

| File | Size | Notes |
|---|---|---|
| `blacksmith.png`, `adventurer.png` | 512×512, RGBA | Composite study (base + 80:20 passes baked); in production → `chr_*` + `_g20` + `_wear` |
| `sword.png`, `armor.png` | 512×512, RGBA | Rune glow baked for the study; in production → `eqp_*` + `_g20` + `_emit` |
| `tree.png` | 512×512, RGBA | Nature: no `_g20` needed beyond line weight; optional |
| `town_view.png` | 1920×1080, RGB | Dusk target, not an asset (becomes `map_town_overview.png` + overlays) |
| `menu_screen.png` | 1920×1080, RGB | Menu target ("Ember & Ash") |
| `font_reference.png` | 1920×1080, RGB | Typography/rarity reference |
| `comparison_85_15_vs_80_20.png` | 1944×2082, RGB | Review sheet: 08 left, 80:20 right; produced by `_generator/compare_hybrids.py`. Use the same name pattern `comparison_<a>_vs_<b>.png` for future review sheets (`_source/review/`) |

---

## 2. Folder layout (`res://`)

08's layout, with 80:20 additions marked `+`:

```text
res://
├── assets/
│   ├── characters/            chr_*.png, chr_*_wear.png, + chr_*_g20.png, + chr_*_pal.png, *_frames.tres
│   ├── equipment/
│   │   ├── icons/             eqp_*.png (128x128), eqp_*_emit.png, + eqp_*_g20.png
│   │   └── held/
│   ├── environment/           trees/, props/, tilesets/
│   ├── buildings/             bld_*.png, bld_*_emit.png (forge mouth, lit windows)
│   ├── maps/
│   ├── ui/                    ornaments/ (+ *_gilt), menu/, theme/chronicle_theme.tres
│   ├── fx/
│   │   ├── overlays/          fx_paper_grain, fx_hatch_overlay, fx_soot_overlay, fx_soot_mask_*, + fx_soot_streak_*
│   │   ├── lights/            fx_light_*.png (+ window, rune ring)
│   │   ├── particles/         fx_ember_*.png, fx_spark_*.png
│   │ + └── runes/             fx_rune_*.png, fx_rune_*_emit.png
│   └── fonts/                 IM Fell English SC, IM Fell English, EB Garamond, Grenze Gotisch; OFL.txt each
├── style/                   + style_dial.tres (presets "p85_15", "p80_20"), + scene_dial_map.tres
├── shaders/                   paper_overlay, line_boil, night_hatch, actor_outline, soot_overlay,
│                              emissive_add, dusk_grade (08) + g20_composite.gdshader (g20 + palette remap)
└── _source/                   (excluded from export) masters, .kra/.psd, sidecars, review/comparison_*.png
```

---

## 3. Dimensions

**Reference resolution 1920×1080**, tile **64×64 px** — as 04/08.

| Asset type | Master | In-game canvas | Notes |
|---|---|---|---|
| Characters | 512×512 | **128×128** | Body ≈ 64–80 px wide |
| Large creatures | 1024×1024 | 256×256 | |
| Item icons | 512×512 | **128×128** | 64 px in slots, 128 px in tooltips |
| Held items / world drops | 512×512 | 64×64 or 128×128 | |
| Trees | 512×512 | 192×192 or 256×256 | |
| Props | 256×256 | 64×64 – 128×128 | |
| Buildings | 4× target | multiples of 64 | Smithy ≈ 256×192, inn ≈ 384×256 |
| Tilesets | 4× target | 64×64 per tile | |
| UI screens / maps | 1920×1080 (or 3840×2160) | 1920×1080 | |
| Ornaments; Grenze initials; gilt corners | vector or 4× | as used | Initial ≈ 96–128 px (menu up to ~240 px); corners ≈ 64–96 px |
| **`_g20`, `_wear`, `_emit`** | same as colour master | **same canvas as the colour sprite** | pixel-aligned, same pivot |
| **`_pal` LUT** | — | 256×2 | one per character or material set |
| Soot overlay (tileable) | — | 1024×1024 | 128–256 px blotch scale |
| **Soot streaks** | — | 128×256 (portrait), placed below chimneys | soft top, fading downhill (south on the map) |
| Placed soot masks | — | power of two, ≤ 1024 | `fx_soot_mask_streets` may be 2048×1024 for the whole village |
| Light textures | — | 256×256 (lantern, candle, window), 512×512 (forge, rune ring) | soft radial, no hard edge |
| **Rune decals** | 4× | ≈ 192×192 for the well ring | thin gilt dashes survive at 1× (≥ 2 px) |
| Ember particles | — | 8×8 – 16×16 | |

### Line weight for target size

| Element (in-game size) | 04 | 85:15 rec. | 80:20 rec. | 80:20 minimum |
|---|---|---|---|---|
| Actor outer contour (incl. silhouette) | 2 px | 3 px | 3–3.5 px | 2.5 px |
| Environment outline | 1.5 px | 2 px | 2 px | 2 px |
| Interior detail | 1 px | 1.5 px | 1.5 px | 1 px |
| Wear marks (scratches, cracks) | — | — | 1 px at 60 % ink | must not read as outline |
| Hatch lines | 1 px, pitch ≥ 3 px | same | same; core shadow pitch 2.5 px | 1 px |
| Icon outline (128 px) | 1.5 px | 2–2.5 px | 2.5 px; **thin icons 2 px** | 2 px |

At a 512 px master for 4× reduction: actor contours ≈ 12–14 px incl. silhouette, thin-icon contour
≈ 11 px, scratches ≥ 4 px wide so they survive as 1 px marks. Runes must be ≥ 16 px tall at master
to stay recognisable (not noise) at 128 px; fewer, larger runes beat many small ones.

---

## 4. Sprite orientation

As 04/08: **straight top-down**, default facing **south**, **4 directions**. Do not mirror asymmetric
characters (pauldron, eyepatch, hammer, tongs, asymmetric soot and scratches). `_g20`, `_wear` and
`_emit` follow their sprite's direction and frame exactly; a mirrored symmetric sprite mirrors all
companion layers with it.

Icons: weapons 45° diagonal tip top-right; armour front view; consumables upright. Runes follow the
item's axis (along the fuller for blades).

---

## 5. Scale consistency

As 04/08: 1 tile = 64 px; blacksmith shoulders ≈ 80 px at 128 px canvas, adventurer ≈ 68 px; doors
64 px, barrels ≈ 40 px, anvil ≈ 56×32 px; canopies 160–240 px. Keep `_source/ref_scale_sheet.png`
with 04, 08 and 80:20 composites side by side. Never fix size with node `scale`.

Light radii: forge ≈ 4–5 tiles, inn door ≈ 3 tiles, inn windows / street lanterns ≈ 2 tiles, candle
≈ 1 tile, rune ring ≈ 2.5 tiles.

---

## 6. Transparency

* PNG, RGBA, **straight (non-premultiplied) alpha**; anti-aliased edge pixels in ink `#20140c`.
* **Not baked into colour sprites:** parchment, paper grain, vignette, soot overlay, glow (incl. rune
  glow), dynamic rim-light, night tint — and **none of the 80:20 additions**. The base colour sprite
  is the 85:15 drawing.
* **Baked in the base:** the 85:15 ink-and-wash drawing, the thin 40 % ember rim, local storytelling
  soot ≤ 5 %, runes as *ink marks* (unlit).
* **In `_g20`:** extra line and silhouette width, the −5 % shadow step (as semi-transparent shadow
  colour), scratches, cracks, nicks, rim boost to 53 % on metal. Alpha only where it adds; transparent
  elsewhere, so `base` alone = 85:15 and `base + _g20` = 80:20.
* `_wear` masks: greyscale, white = soot allowed; strength comes from the preset.
* `_emit` masks: ember `#e6702a` with `#ffc070` cores on transparency, inside the silhouette (≤ 2–3 px
  beyond). Rune ring decals: gilt `#b8923e` ink in the colour layer, glow in `_emit`.
* Light textures: white-to-transparent radial; colour from `PointLight2D.color`.
* Trim nothing at export; all layers share canvas and pivot.

---

## 7. Pivot & anchoring

| Asset | Pivot | Godot setup |
|---|---|---|
| Characters | Feet centre (≈ y 0.80) | `centered = true`, `offset.y = -(0.30 × h)`; Y-sort on origin |
| Trees | Trunk base | origin at trunk base |
| Buildings, props | Bottom-centre of footprint | origin at south wall centre |
| Icons | Centre | `centered = true` |
| `_g20` / `_wear` / `_emit` | **identical to their sprite** | sampled in the same material, or child `Sprite2D` with identical offset |
| Soot streaks | Top-centre at the chimney | world-space `Sprite2D`, z above roof |
| Rune decals | Centre of the ring | world-space `Sprite2D` on the ground layer, below actors |
| Light textures | Centre | `PointLight2D` at forge mouth, door, window, lantern flame, ring centre |
| Ember emitters | Emitter point | `GPUParticles2D` at forge mouth / torch |
| Overlays | Top-left (tileable) or world position | `CanvasLayer` or world-space |

---

## 8. Godot 4.x import recommendations

**Textures** — as 04/08: filter **Linear**, mipmaps off at 1:1 (on for zoomed-out maps), compression
**Lossless**, `fix_alpha_border = true`, `premult_alpha = false`. Additionally:

* `_g20`: **Lossless** (thin scratch lines and outline edges); same import settings as its sprite so
  filtering matches.
* `_emit` and `fx_rune_*`: **Lossless**.
* `_wear`, `fx_soot_*`, `fx_light_*`: Lossy (WebP ≥ 0.85) or VRAM-compressed are fine.
* `_pal` LUTs: filter **Nearest**, Lossless, no mipmaps.
* Tileable overlays: `texture_repeat = Enabled`.

**World rendering — both presets in one resource**

`res://style/style_dial.tres` holds the values below; `scene_dial_map.tres` maps scene types to a
preset (default per README verdict: daytime exteriors and their characters → `p85_15`; items, UI,
forge, interiors, dusk, night → `p80_20`). Switch with a short tween (≈ 1 s) on scene change or time
of day.

| Parameter | `p85_15` | `p80_20` |
|---|---|---|
| `g20_strength` (opacity of `_g20` layer) | 0 | 1 |
| `palette_row` (`_pal`) | 0 | 1 |
| `actor_outline` width (master px) | 1.2 | 1.5 (thin icons 1.2) |
| `CanvasModulate` dusk / night / interior | `#d8c8b0` / `#6c6a80` / `#8a7a6a` | `#d4c2a8` / `#66647a` / `#827262` |
| `dusk_grade` multiply | 6 % → 15 % | 6 % → 19 % |
| Night hatch max density vs 04 | +25 % | +30 % |
| Forge light energy | 1.0–1.4 | 1.2–1.7 |
| Inn / lantern / window energy | 0.5–0.8 | 0.6–1.0 |
| Candle energy | 0.3–0.5 | 0.35–0.6 |
| Extra faint pools | off | ≤ 0.25 |
| Rune ring light (`#e0b860`) | 0.2 | 0.3–0.5, slow pulse |
| `soot_strength` | 0.6 | 0.8 (interiors 0.9) |
| Street soot (`fx_soot_mask_streets`) | off | 7 % (dusk/night only) |
| Chimney streaks | off | on |
| `_emit` pulse (legendary) | 0.6–1.0 | 0.7–1.0 |
| Ember particle amount | ×1.0 | ×1.33 |
| Vignette `#3a2410` at corners | 50 % | 55 % (danger 70 %) |

* `g20_composite.gdshader`: samples base, `_g20` (mixed by `g20_strength`) and remaps colour through
  `_pal` by `palette_row`; this is the only shader the 80:20 register adds.
* `_emit`: additive, `light_mode = Unshaded`, so runes stay visible under `CanvasModulate`.
* **No normal maps and no `LightOccluder2D` by default** (unchanged from 08).
* Animated characters: `_g20` and `_wear` frames packed in sheets matching the colour sheet
  (`chr_blacksmith_walk_s_sheet.png`, `…_sheet_g20.png`, `…_sheet_wear.png`); same `SpriteFrames`
  region per frame.

**Window & UI** — as 04/08 (1920×1080, `canvas_items`, `expand`; test 1280×720 and 2560×1440). Theme
`chronicle_theme.tres` with 08's font types, plus:

* `InitialLabel`: Grenze 800 for "E" (Grenze Gotisch for initials that stay legible), MSDF on,
  hinting None, colour `#7e2418`, shadow `#e6702a` at ~60 %, 14 px blur; initials only.
* Rubric/accent colour `#7e2418`; panel parchment `#dcc79a` (or `#e2cea2` for text-heavy panels).
* Gilt `#b8923e`: `StyleBoxTexture` inner frame (1 px, inset 8 px), label underlines, corner
  ornaments via `ui_corner_gilt_*`. **No font colour may use gilt** (1.8:1).
* Dark `StyleBoxFlat` for tooltips and dialogue (`#2a1c12` → `#140e08`, border `#6e4a2a`), dialogue
  inner glow ~22 %; speaker `#ff9a48`, choices `#f0d060`; Legendary `#ffa050` + glow.
* Rarity colours per README tables; small-text fallbacks Rare `#634c00`, Legendary `#7e2e0a`, Set
  `#245a2c` on `#dcc79a`.

---

## 9. Consistency notes

* **Interchangeability rule:** an 85:15 asset and its 80:20 form share file name, canvas, pivot,
  silhouette and geometry. They differ only in `_g20` (line, shadow step, wear marks), palette row,
  `_wear` strength, `_emit` strength and light/grade presets. If a change needs anything else, it is
  a new asset, not a register.
* Every asset is reviewed as a pair (base and base + `_g20`) next to its 04 counterpart; reject if
  the 80:20 composite exceeds the README ceilings (0.25 day, 0.30 items, 0.35 night/interiors) or the
  85:15 composite exceeds 0.25.
* Runes and `_emit` exist only for magical/legendary items, forge/fire and magical places; ordinary
  gear gets wear in `_g20` and nothing in `_emit`.
* One soot overlay, one set of soot streaks and one set of light textures for the whole game;
  per-asset differences live in `_wear`, `_g20` and light energy.
* Gilt appears only in UI ornaments, the map frame and rune decals.
* Review screenshots of dusk, night and interiors are taken in-engine with the preset applied, never
  painted. Review sheets go to `_source/review/comparison_<a>_vs_<b>.png`.
* Keep `OFL.txt` for all four families in `res://assets/fonts/` and list them in the credits.
