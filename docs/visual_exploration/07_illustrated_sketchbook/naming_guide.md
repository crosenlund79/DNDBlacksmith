# Naming & Asset Guide — 07 Illustrated Sketchbook Fantasy ("Tales from the Anvil")

Conventions for producing and importing assets in this direction into Godot 4.x. All numbers are
tuned for ink-and-watercolour sprites on a **64 px tile grid** in a **straight top-down** view, drawn
over a **separate tiled paper layer**.

---

## 1. Filename conventions

- **snake_case**, lowercase ASCII, no spaces, no version numbers in shipped names (use git).
- Pattern: `<prefix>_<subject>[_<variant>][_<action>][_<direction>][_<frame>].png`
- Frame numbers are **two digits, 1-based** (`_01`…`_12`). Directions use compass letters.

| Prefix | Category | Examples |
|---|---|---|
| `chr_` | Characters, NPCs, creatures (and rig parts) | `chr_blacksmith_walk_s_04.png`, `chr_adventurer_idle_e_01.png`, `chr_blacksmith_part_beard.png` |
| `eqp_` | Equipment & item icons | `eqp_sword_longsword_teal_gem.png`, `eqp_armor_plate_breastplate.png`, `eqp_mat_iron_ingot.png` |
| `env_` | Flora, rocks, props, wash tiles, ground decals | `env_tree_oak_01.png`, `env_rock_cluster_02.png`, `env_wash_grass_a.png`, `env_decal_pencil_grass_03.png` |
| `bld_` | Buildings, roofs, cut-away interiors | `bld_smithy_roof.png`, `bld_smithy_interior_floor.png`, `bld_inn_tipsy_wyvern_roof.png` |
| `bg_` | **Paper and other full-screen backgrounds** (tiling) | `bg_paper_plain_512.png`, `bg_paper_grid_512.png`, `bg_paper_plain_1024.png` |
| `ui_` | UI kit, HUD, menus | `ui_button_ink_9s.png`, `ui_button_ink_hover.png`, `ui_panel_paper_9s.png`, `ui_splash_teal_01.png` |
| `fx_` | Effects, particles, light textures, shadows, overlays | `fx_spark_01.png`, `fx_magic_wisp_teal_02.png`, `fx_shadow_tree_m.png`, `fx_glow_forge.png` |

Suffixes:

| Suffix | Meaning |
|---|---|
| `_s _n _e _w` | 4-direction facing (south default) |
| `_se _sw _ne _nw` | Extra diagonals for 8-direction sets |
| `_idle _walk _run _hammer _interact _hit` | Action |
| `_boil_a _boil_b _boil_c` | Line-boil variants of the same frame/part (cycled for a living line) |
| `_part_<name>` | Cut-out rig part (`_part_arm_upper_l`) |
| `_9s` | 9-slice UI texture |
| `_normal _hover _pressed _disabled` | UI states |
| `_512 _1024` | Texture size, **only on tiling `bg_` textures** (several sizes may coexist) |
| `_nrm` | Normal map (avoids a clash with north `_n`) |
| `_master` | Source masters (never in `res://`) |

Examples: `chr_blacksmith_idle_s_01_boil_b.png`, `chr_blacksmith_hammer_e_03.png`,
`env_tree_oak_autumn_02.png`, `bg_paper_plain_512.png`, `ui_button_ink_pressed.png`.

The example files in this folder keep the shared exploration names (`blacksmith.png`,
`paper_plain.png`, …); in production they would become `chr_blacksmith_idle_s_01.png`,
`bg_paper_plain_512.png`, `bg_paper_grid_512.png`, etc.

---

## 2. Folder layout

```text
res://
├── assets/
│   ├── backgrounds/
│   │   └── paper/               # bg_paper_plain_512.png, bg_paper_grid_512.png, overlay material
│   ├── characters/
│   │   ├── blacksmith/          # parts, boil variants, rig scene, SpriteFrames .tres
│   │   ├── adventurers/
│   │   └── villagers/
│   ├── equipment/
│   │   ├── weapons/
│   │   ├── armor/
│   │   └── materials/
│   ├── environment/
│   │   ├── washes/              # semi-transparent ground wash tiles + TileSet .tres
│   │   ├── decals/              # pencil grass marks, stones
│   │   ├── flora/
│   │   ├── rocks/
│   │   └── props/
│   ├── buildings/               # roofs + interiors
│   ├── fx/
│   │   ├── particles/
│   │   ├── lights/
│   │   └── shadows/
│   ├── shaders/                 # paper_overlay.gdshader, line_boil.gdshader, outline_teal.gdshader
│   ├── ui/
│   │   ├── kit/
│   │   ├── icons/
│   │   ├── menu/
│   │   └── themes/              # ui_theme_sketchbook.tres
│   └── fonts/
│       ├── fondamento/
│       ├── amatic_sc/
│       ├── shantell_sans/
│       └── LICENSES/            # OFL.txt per family
└── scenes/ …
```

Masters (512 px icons, 256 px character parts, layered `.kra`/`.psd` with ink, pencil and wash on
separate layers) live **outside** `res://` in `art_source/`, mirroring the same structure.

---

## 3. Suggested dimensions

| Asset | Final in-game size | Master | Notes |
|---|---|---|---|
| Paper (plain) | **512×512** tile, repeated | 512 or 1024 | Seamless; 1 texel = 1 world px at 1× zoom; average ≈ `#f1e6cf` |
| Paper (grid) | 512×512 tile | 512 | Grid pitch divides 512 exactly (e.g. 32 or 64 px) |
| Ground wash tile | **64×64** | 128×128 | Semi-transparent washes over paper; painted as seamless 512 sheets, sliced |
| Character frame / canvas | **128×128** | 256×256 (2×) | Smith's shoulders ≈ 84 px; adventurer ≈ 72 px |
| Character rig part | fits 128 canvas | 256 px | Overlap joints 6–10 px; ink line hides seams |
| Item icon | **128×128** | 512×512 | Shown at 64 px in grids, 128 px in tooltips |
| Small prop / rock | 64×64 | 128×128 | 1 tile footprint |
| Large prop (anvil yard, cart) | 128×128 / 192×128 | 2× | Multiples of 64 |
| Tree | 192×192 / 256×256 | 2× | Canopy 3–4 tiles; trunk footprint 1 tile |
| Cottage roof | 192×192 | 384×384 | 3×3 tiles |
| Smithy (roof + interior set) | 256×256 | 512×512 | 4×4 tiles; interior floor/walls/props as separate layers |
| Inn "The Tipsy Wyvern" | 384×320 | 2× | 6×5 tiles, L-shape |
| UI | 1920×1080 reference | 2× for hero art | 9-slice ink frames over paper panels |
| Key art / menu background | 1920×1080 | 3840×2160 | Opaque (paper composited) |

**Line weight at target size.** A 2.6 px line on a 512 master becomes 0.65 px at 128 px and
disappears. Final sprites need the contour **redrawn or thickened for target size**:
actor contour ≈ 2 px, environment contour ≈ 1.5 px, interior lines ≈ 1 px at 1× zoom. Draw at 2× of
final (256 px for a 128 px canvas) with 4 px / 3 px / 2 px lines.

The example PNGs in this folder are at **master** size, not final game size.

---

## 4. Sprite orientation & alignment

- **Straight top-down**: scalp, shoulders, beard from above, toes peeking out — never a face or a
  building wall (except walls seen from above in roof-removed interiors).
- **Default facing: south.**
- **4 directions** (S, N, E, W) for all characters; 8 optional for the protagonist only.
- **Mirroring caveats:** the cast is asymmetric (smith: single *left* pauldron, hammer in the *right*
  hand, tongs at the *left* hip; adventurer: sword right, dagger left). Mirroring also flips the
  top-left light and turns the −35° pencil hatching into +35°. Therefore draw W separately, or mirror
  only the body rig and re-attach asymmetric parts, and redraw hatching/shadow washes on mirrored parts.
  Symmetric props may be mirrored if their shadow is a separate sprite.
- **Alignment over paper:** sprites are positioned on whole pixels at 1× (Godot:
  `rendering/2d/snap/snap_2d_transforms_to_pixel` on for the world, or snap the camera) so thin ink
  lines don't shimmer against the paper grain while scrolling.
- **Boil variants** (`_boil_a/b/c`) share exactly the same canvas, pivot and silhouette — only the
  line wobble differs. Diff-check that the silhouette doesn't jump more than 1 px.

---

## 5. Scale consistency

- One world unit = 1 px at 1× zoom; tile = 64 px; paper tile = 512 px (8×8 game tiles).
- Keep `art_source/scale_sheet.png` (see `prompts.md` §4) **on top of `paper_plain`**: smith,
  adventurer, villager, door, barrel, rock, cottage, tree, anvil on the 64 px grid.
- Scale reference is **shoulder width**: smith ≈ 1.3 tiles, adventurer ≈ 1.1, villager ≈ 1.0,
  child ≈ 0.7.
- The paper is never scaled to fit something; if a zoomed-out view makes the grain too fine, use the
  1024 version rather than scaling the 512 one.
- Never scale sprites in-engine to fix a size error; re-export from the master.

---

## 6. Transparency

- PNG RGBA, **straight (non-premultiplied) alpha**, sRGB.
- **No paper in sprites, ever.** Sprites ship on full transparency; the paper comes from the
  background layer (and optionally the overlay shader).
- **Decision on watercolour opacity:** sprite **bodies are opaque** (alpha 255). The mock-ups render
  fills at ~88–90 % so a hint of paper shows through, but in game semi-transparent bodies would ghost
  when sprites overlap (a character behind a tree trunk, a cart in front of a fence) and would change
  colour depending on what lies beneath. So:
  - fills: opaque; pick colours that already *look* like a wash on cream paper (the palette ramps do);
  - outer edge: soft, 1–2 px anti-aliased at final size; a slightly irregular wash edge is fine, but
    the soft zone must not exceed ~2 px;
  - semi-transparent **by design** only: contact/cast shadow washes, ground wash tiles (grass, road,
    water), magic and fire glows, smoke, splashes and other FX;
  - the paper-grain overlay shader adds the "on paper" feel to opaque sprites.
- **Halos:** pale washes keyed from white or cream leave light fringes that show on darker washes.
  Generate on mid-grey, colour-decontaminate, keep *Fix Alpha Border* on, and check every sprite at
  1× over both `paper_plain` and a dark tooltip colour (`#3a2e28`).
- **Padding:** ≥ 4 px empty border per frame/region at final size (8 px at 2×), more where blurred
  shadows extend. Atlas packing: 2 px extrusion.
- **Shadows:** contact shadows inside character frames (soft `#6a5a4a` wash @ ~22–30 % plus pencil
  strokes); long cast shadows for trees/buildings as separate `fx_shadow_*` sprites.

---

## 7. Paper textures

| Texture | File | Role | Import |
|---|---|---|---|
| Plain sketchbook paper | `bg_paper_plain_512.png` (from `paper_plain.png`) | **Primary** world ground and UI page | Lossless, Linear, mipmaps on |
| Squared paper | `bg_paper_grid_512.png` (from `paper_grid.png`) | Optional crafting / blueprint / inventory screens | Lossless, Linear, mipmaps on |
| Plain paper, large | `bg_paper_plain_1024.png` | Optional, for zoomed-out views or a less visible repeat | Lossless or VRAM high quality |

- **Seamless tiling** is required on both axes; test by tiling 3×3 before import.
- **Repeat:** in Godot 4 repeat is **not** an import flag (it was in Godot 3). Set it on the node:
  `CanvasItem.texture_repeat = TEXTURE_REPEAT_ENABLED` on the paper `Sprite2D`/`TextureRect`
  (or project-wide `rendering/textures/canvas_textures/default_texture_repeat` — not recommended, it
  affects all sprites), or `repeat_enable` on the sampler in a shader.
- **Filter:** Linear (`texture_filter = Linear Mipmap` on the paper node if the camera zooms out
  below ~0.7×, to stop grain from shimmering). Mipmaps **on** for paper only.
- **World-space scale:** 1 texel = 1 world px at 1× zoom. Use a `Sprite2D` with `region_enabled = true`
  and `region_rect` covering the level bounds (plus a margin), as a child of the world, `z_index` −100.
  For an "infinite" page, a full-screen `ColorRect` with a shader that samples the paper by
  **world position** (pass the camera's canvas transform as a uniform) also works — never sample by
  `SCREEN_UV` alone, or the paper sticks to the screen.
- **Overlay (optional):** a second paper `Sprite2D` above the entities, `z_index` +100, offset by
  a non-multiple of 64 (e.g. 173, 211 px) so its grain doesn't line up with the base layer, material:

  ```glsl
  shader_type canvas_item;
  render_mode blend_mul;
  uniform float strength : hint_range(0.0, 0.2) = 0.08;
  void fragment() {
      COLOR = mix(vec4(1.0), texture(TEXTURE, UV), strength);
  }
  ```

  Keep `strength` 0.06–0.10. Exclude UI (it lives on its own `CanvasLayer`).
- **Day/night:** with option A (README → *Lighting*) the paper sits in the world canvas and is tinted
  by `CanvasModulate`; with option B put it on a `CanvasLayer` (layer −1, `follow_viewport_enabled =
  true`) so it is excluded from the world's `CanvasModulate`.

---

## 8. Pivot & anchoring

| Asset | Pivot / offset | Y-sort origin |
|---|---|---|
| Characters | **Feet centre** (centre of contact shadow), ~`(64, 76)` on a 128 canvas | Same point |
| Trees | **Trunk base**, not canopy centre | Trunk base |
| Rocks | Bottom-centre of the footprint | Same |
| Buildings / roofs | **Footprint bottom-centre** | Footprint bottom-centre |
| Interior pieces (floor, walls, forge) | Floor: top-left of the building footprint (tile-aligned); props: bottom-centre | Floor not y-sorted (below entities); props y-sorted |
| Props | Bottom-centre of footprint | Same |
| Paper / wash tiles | Top-left, tile-aligned (paper: world origin) | n/a (below entities) |
| Icons, UI | **Centred** | n/a |
| FX | Centred (particles), base for smoke columns | n/a or emitter base |

Use `Sprite2D.centered = true` with `offset` so the pivot lands on the node origin (or `centered =
false` with explicit `offset`) — consistently per category, documented in `character_base.tscn`,
`prop_base.tscn`. **Roof removal:** roofs are separate sprites over the interior; fade
`modulate.a` to 0 when the player enters (an `Area2D` on the footprint).

---

## 9. Godot import recommendations

| Setting | Recommendation | Why |
|---|---|---|
| Texture filter (project default) | **Linear** | Ink and wash art; Nearest makes wobbly lines jagged |
| Mipmaps | **Off** for characters, props, UI; **On** for paper (and large backgrounds) when zooming out below ~0.7× | Sharp sprites; no grain shimmer |
| Compression | **Lossless** for sprites, icons, UI, wash tiles and paper (subtle paper noise bands under VRAM compression); VRAM Compressed (BPTC/ASTC high) only for big opaque key art | Soft washes and fine grain suffer from lossy formats |
| Fix Alpha Border | On | Prevents halos on soft wash edges |
| Repeat | Per node (`texture_repeat`), only on paper and wash-tile materials that need it | Godot 4 has no import repeat flag |
| Pixel snap | `rendering/2d/snap/snap_2d_transforms_to_pixel = true` (or camera snapping) | Thin ink lines stay stable over the grain |
| Y-sort | `y_sort_enabled` on the entities node; TileMapLayer with Y-sort for props | Correct overlap |
| Time of day | Option A: `CanvasModulate` day `#ffffff` → dusk `#e0c8c0` → night `#6a7090`, tinting paper + sprites; `PointLight2D` forge/lanterns `#ff9a3a` (Add), magic `#1fb5d6` / `#9a5cf0` | Unified page lighting (option B: paper on its own CanvasLayer) |
| Line boil | `AnimatedSprite2D` cycling `_boil_*` variants at 6–8 fps, or `line_boil.gdshader` (noise UV offset 0.5–1 px, stepped at 8 fps) | Living line on idle characters and UI |
| Hover / selection | `outline_teal.gdshader` (wobbly teal outline) or a hand-drawn teal ring sprite under the target | Accent signals interactables |
| Animation | `Skeleton2D` + `Polygon2D` + `AnimationPlayer` for rigs; `AnimatedSprite2D` + `SpriteFrames` for loops and FX | See README |
| Atlases | One atlas per character / icon category; paper textures **not** atlased (they must repeat) | Repeat only works on standalone textures |
| Stretch | `canvas_items`, aspect `expand`, base 1920×1080 | Crisp text and UI |
| UI | `ui_theme_sketchbook.tres`: `StyleBoxTexture` 9-slice ink frames on paper panels, Shantell Sans default, Amatic SC 700 `Heading` (≥ 32 px), Fondamento `Title`, `shantell_numbers_tnum.tres` for stats, both rarity sets as named colours | Single source of truth |
| Fonts | `FontFile`; MSDF for Fondamento; raster for Amatic SC and Shantell Sans | See README → Typography |

### Quick checklist before committing an asset

- [ ] Name follows §1 and sits in the right `res://assets/...` folder
- [ ] Final size from §3; contour redrawn/thickened for target size; master in `art_source/`
- [ ] No paper in the sprite; body opaque; straight alpha; no halo at 1× over paper and over `#3a2e28`
- [ ] Faces south (or correct suffix); asymmetric parts, light and hatching correct after any mirroring
- [ ] Pivot per §8; Y-sort verified next to the scale sheet over `paper_plain`
- [ ] Import: Linear, mipmaps per §9, Lossless; paper textures seamless, repeat set on the node
