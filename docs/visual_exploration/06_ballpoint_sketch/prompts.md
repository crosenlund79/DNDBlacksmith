# Prompts — 06 Ballpoint Sketch Fantasy · "The Inkbound Forge"

Prompts for producing production-quality versions of the eleven assets (and new ones) with an
image model, or for briefing an illustrator. The example PNGs in this folder are procedural SVG
style studies (see [README](README.md#rendering-note-read-first)); use them as composition, tone
and layer references, not as quality targets.

**Reference images:** the client's two new reference images (the first defines the architectural
sketchbook look) were **not present** in the repository or build session. These prompts are written
from the client's description. Once the references are added (e.g. `docs/visual_exploration/references/`),
re-check line weight, hatch density, amount of construction lines and the blue/red values against
them, and feed the first reference as a style reference on every generation.

---

## 1. Master style prompt

Prefix every **sprite** prompt with this block (adapt syntax to the model: weights, `--no`, etc.).
Paper textures use their own prompts (4.9, 4.10) without it.

```text
Hand-drawn blue ballpoint pen illustration from an architect's sketchbook. Single blue biro ink
(#1f3a93) on white, confident but imperfect contours, many lines gone over twice with a slightly
offset second stroke, faint construction lines (centre axis, guide circles) left visible, small
overshoots at corners. Tone built only from pen hatching: parallel diagonal strokes, crosshatching
and triple hatching on the shadow side, untouched white paper for highlights; no solid fills, no
grey wash, no smudging. Light from the top-left, shadows and hatched ground shadow toward the
bottom-right. Red ballpoint (#c62828) used sparingly for magic, gems, fire and one key item only.
Naturalistic proportions. Straight top-down orthographic view looking directly down (we see tops
of heads, shoulders, roofs and tree canopies), no perspective, no 3/4 angle. Strong, readable
silhouette, clean game-asset quality.
```

### Master negative prompt

```text
3/4 view, isometric, perspective, side view, horizon, photorealistic, 3D render, CGI, colour
painting, watercolour, markers, pencil graphite, charcoal, black ink, multiple pen colours, gel pen
glitter, solid fills, grey wash, gradients, smudge, airbrush, cel shading, thick cartoon outlines,
chibi, big head, anime, pixel art, blurry, lined paper, grid paper, notebook background, paper
texture, desk, hand holding pen, text, handwriting, letters, numbers, watermark, signature, frame,
border, glow, lens flare, modern objects
```

---

## 2. Consistent artistic & technical requirements

| Item | Lock |
|---|---|
| Camera | Straight top-down orthographic (icons: icon-specific views below) |
| Light | Top-left; shadow sides bottom-right; ground shadow toward bottom-right |
| Ink | Blue `#1f3a93`, ~2 px line at 512 px master, double-passed contours; actors' silhouette slightly heavier |
| Red | `#c62828` only for gems/magic, fire, the adventurer's cloak / one signature item; ≤ ~10 % of a sprite |
| Hatch | One screen-space stroke direction set for all assets; spacing ~4–6 px, stroke ~1 px at 512 px |
| Tone per material | 0 skin/beard/shirt · 1 metal/wood/foliage/roofs/stone/water · 2 leather/apron/slate · 3 boots/straps |
| Fill | **Opaque** very pale paper-white / pale-blue tint inside every shape (README palette) — never transparent interiors |
| Construction lines | Faint, ~15–25 % strength; standalone sprites and icons only, not in-game animation frames |
| Ground shadow | Hatched ellipse, never a filled blob |
| Proportions | Naturalistic (head 0.98×, shoulders 1.0×, belly 1.0× of base geometry) |
| Background | Sprites: transparent, **no paper**. Paper: separate seamless tiles. Compositions: tiled paper |
| Text | Never let the model letter text; titles, labels and annotations are added in post or live in Godot |

---

## 3. Transparent background & framing rules

* Sprites and icons are **pen + opaque pale fill on transparency**. Grid or plain paper comes from
  the game's separate paper layer: **never bake paper, grid lines, paper grain or a page edge into a
  sprite**. If the model cannot output alpha, generate on flat pure white `#ffffff` with a
  *different* pale fill inside the shapes (ask for "very pale blue-white fills"), then remove only
  the white connected to the canvas border (flood-fill / magic wand from the corners, soft edge).
  The interior fill must stay opaque.
* 512×512 master canvas, subject centred horizontally, ≥ 24 px empty margin on every side;
  construction lines may extend into the margin but stay ≥ 8 px from the edge.
* Characters: feet at ≈ y 410, hatched ground shadow beneath, facing south (down the image).
* Nothing touching the canvas edge; no cropped weapon tips.
* Paper textures: 512×512, seamless on all four edges, **no sprites, no drawings, no text**.
* Compositions are 1920×1080, 16:9, no transparency, built from layers (paper + sprites + UI).

---

## 4. Individual prompts

Each sprite prompt = **Master style prompt + the text below**. Negative = master negative + extras.

### 4.1 `blacksmith.png` — protagonist

**Purpose:** player-character master; defines scale, line weight and tone for all actors.

```text
Single character sprite, straight top-down view from directly above, facing south (down the image).
An older, heavyset retired adventurer who is now the village blacksmith. Bald scarred scalp seen
from above, drawn as a clean circle with a few scar ticks, a short grey fringe at the back in light
hatching, a thin eyepatch strap crossing the head diagonally. Big braided beard projecting forward
over a large belly, left as clean white paper with only outline and braid strokes, a small gold ring
in the braid. Leather apron with pocket and scorch marks in crosshatching, apron straps crossing his
broad back in dense triple hatching. A single dented steel pauldron on his left shoulder with a
clean highlight streak. Leather bracers, bare forearms. Heavy sledgehammer hanging from his right
hand (viewer's left), iron tongs at his left hip. Boot toes below the belly in dense hatching.
Faint construction lines: vertical centre axis and a guide circle around the head. Hatched elliptical
ground shadow toward the bottom-right. Opaque very pale fills inside all shapes. Isolated on a
transparent background, no paper, centred, full figure in frame.
```

* **Negative extras:** `face visible from front, eyes looking at viewer, two pauldrons, helmet, hair on top of head, thin body, red on the blacksmith`
* **Canvas:** 512×512, transparent, feet centre at (256, ~410), ≥ 24 px margin.
* **Consistency:** scale and tone reference; save the seed and use as image reference for every
  other character. Pauldron on *his* left (viewer's right), hammer viewer's left. No red on him —
  red appears only when he holds a magic item or works the forge.

### 4.2 `adventurer.png` — visiting adventurer

**Purpose:** NPC/party member; tests the slimmer body and the red signature item.

```text
Single character sprite, straight top-down view from directly above, facing south. A younger,
slimmer adventurer at the same scale as the blacksmith. Long cloak drawn and hatched in red
ballpoint, the only red element. Round wooden shield with a metal boss slung on the back over the
cloak, wood grain in light blue strokes, boss with a clean highlight. Hair in a ponytail with a
headband, steel pauldrons on both shoulders, leather jerkin in crosshatching, bracers, drawn sword
held point-forward in the right hand, dagger at the left hip, boots in dense hatching. Faint centre
axis construction line. Hatched elliptical ground shadow toward the bottom-right. Opaque very pale
fills. Isolated on a transparent background, no paper, centred.
```

* **Negative extras:** `bulky, heavyset, helmet covering head, bow, magic effects, red on shield or sword`
* **Canvas:** 512×512, transparent, feet centre at (256, ~410).
* **Consistency:** shoulder width ≈ 85 % of the blacksmith's; identical line and hatch direction;
  red limited to the cloak (cloak tint `#f8dedb`, hatch `#c62828`).

### 4.3 `sword.png` — inventory icon

**Purpose:** item-icon master (exported at 128×128).

```text
Inventory icon of a single longsword drawn as a design sketch, lying diagonally at 45 degrees, tip
to the top-right, pommel bottom-left. Blade with a central fuller and small rune marks, single
hatching along the lower-right edge, a clean white highlight streak along the upper edge. Curled
crossguard with a central gem drawn and hatched in red ballpoint, round pommel, grip wrapped in
criss-cross binding in dense hatching. Faint construction lines: a straight axis along the blade
running past tip and pommel, a small guide circle around the gem. Opaque very pale fills. Isolated
on a transparent background, no paper, centred, filling about 80 % of the frame.
```

* **Negative extras:** `hand holding sword, scabbard, glow, sparkles, multiple swords, blood, red blade`
* **Canvas:** 512×512, transparent, centred, ≥ 32 px margin.
* **Consistency:** all weapon icons 45°, tip top-right; red only on gems/enchantments.

### 4.4 `armor.png` — inventory icon

**Purpose:** armour-icon master; shows how much detail the pen tolerates on equipment.

```text
Inventory icon of a plate armour set seen from the front, no wearer, drawn as a design sketch:
breastplate with a central ridge and a small anvil emblem, gorget, three-lame pauldrons on both
shoulders, faulds and two tassets, leather side straps and buckles in dense hatching, rivets as
small circles. Steel plates with single hatching and crosshatching on the right-hand side of each
plate, clean white highlight streaks on the left. Faint vertical symmetry axis and a few horizontal
guide lines through shoulders and waist. Opaque very pale fills. Isolated on a transparent
background, no paper, centred, symmetrical.
```

* **Negative extras:** `person wearing it, helmet, arms, legs, mannequin, stand, glow, red armour`
* **Canvas:** 512×512, transparent, centred, ≥ 32 px margin.
* **Consistency:** armour icons always front view, symmetric, lit from top-left; red only if the
  piece is enchanted (e.g. a red gem in the emblem).

### 4.5 `tree.png` — environment

**Purpose:** canopy master for forests and the village.

```text
Single deciduous tree seen straight from above as in an architect's site plan: rounded canopy of
overlapping foliage clusters, each cluster outlined with a loose scalloped pen line, single
hatching inside, crosshatching on the lower-right side of each cluster, a few clean white gaps on
the upper-left. Trunk base just visible. Faint guide circle marking the canopy extent. Hatched cast
shadow toward the bottom-right. Opaque very pale fills. Isolated on a transparent background,
no paper, centred.
```

* **Negative extras:** `side view, visible trunk length, roots, pine, flowers, fruit, red`
* **Canvas:** 512×512, transparent; anchor = trunk base.
* **Consistency:** foliage tone 1, second species tone 2; 3–4 variants per species, plus 2–3 boil
  re-traces per variant for idle sway.

### 4.6 `town_view.png` — Brindlewick on grid paper

**Purpose:** key art for the world view; proves top-down fit and annotation language.

```text
Straight top-down architectural site-plan sketch of a small medieval fantasy village in blue
ballpoint pen. Central crossroads square with a stone well and a market stall. South-west the
blacksmith's workshop with a slate roof drawn as short stroke rows, a chimney and an open forge yard
with anvil, forge (forge fire in red ballpoint), quench trough and rack. North-east the inn, the
largest building, L-shaped with a tiled roof, stable and beer-garden tables. Cottages, a small
chapel, fences, crates, barrels. A stream with ripple hatching and a wooden bridge on the east side.
Forest edges to the north and west as massed scalloped canopies. Tiny figures. Architect-style
leader lines, dimension lines with tick marks and empty label boxes. Hatched shadows to the
bottom-right. Drawn over a faint blue-grey squared grid.
```

* **Negative extras:** `perspective, isometric buildings, visible side walls, legible text, colour fills, compass rose ornament, parchment`
* **Canvas:** 1920×1080, no transparency. Production build: tiled `paper_grid.png` underneath, the
  village as transparent layers on top — generate the village without the grid if possible.
* **Post:** labels in Architects Daughter blue ("The Smithy", "The Tipsy Wyvern", "Market Square",
  "Chapel"), dimension notes (e.g. "4 × 3"), red circle + note on the smithy door.
* **Consistency:** 1 tile = 64 px = two 32 px grid squares; inn ≈ 6×4 tiles, smithy ≈ 4×3 incl. yard.

### 4.7 `menu_screen.png` — main menu

**Purpose:** UI key art; establishes blue-ink UI elements.

```text
Main menu background: a flat sheet of squared notebook paper filling the frame, seen from directly
above. Left half: empty space for a title, below it six hand-drawn rectangular button outlines in
blue ballpoint with slightly overshooting corners, double-passed edges and light hatching on the
bottom-right edge of each. Right half: a loose blue ballpoint sketch of an anvil and hammer with
construction lines and a few red sparks, and small margin doodles. No text.
```

* **Negative extras:** `legible text, gibberish letters, glossy buttons, gradients, desk, pen object, perspective`
* **Canvas:** 1920×1080, no transparency (screen-space paper is correct for menus).
* **Post:** all text live in Godot: title "The Inkbound Forge" (Caveat 700, blue, red scribbled
  underline), buttons Continue / New Game / Load Game / Settings / Credits / Quit (Patrick Hand),
  hover = red hand-drawn circle or arrow, version label (Kalam 18 px).

### 4.8 `font_reference.png` — typography sheet

**Purpose:** UI implementation reference, not for generation. Build it in Godot or a layout tool.

```text
Typography reference sheet on squared paper #f7f6f0, ink #1f3a93. Sections: title "The Inkbound
Forge" in Caveat 700 with red underline scribble; headings and annotations in Architects Daughter;
UI and dialogue text in Patrick Hand 18-24 px; stats table in Kalam with right-aligned columns;
button states (normal, hover with red circle, pressed with crosshatch fill, disabled at 40 % ink);
item names in the six rarity colours on paper and again on a dark navy-ink tooltip.
```

* **Canvas:** 1920×1080. Use exact hex values from the README rarity tables; never let an image
  model render this.

### 4.9 `paper_grid.png` — squared notebook paper (background tile)

**Purpose:** the world's ground; tiled in world space under all environment layers.

```text
Seamless tileable texture of squared notebook paper, viewed perfectly flat and evenly lit. Off-white
paper (#f7f6f0) with thin, faint blue-grey grid rules forming exact 32-pixel squares (16 × 16 squares
on a 512 px tile), rules perfectly straight and evenly spaced, very subtle paper fibre noise and
faint stitched-looking irregularity in the rules. Pattern repeats seamlessly on all four edges.
Empty paper only: no drawings, no sprites, no text, no margins, no hole punches, no shadows,
no vignette, no page edge, no perspective.
```

* **Negative extras:** `drawing, sketch, ink marks, text, red margin line, spiral binding, hole punches, folds, coffee stains, vignette, lighting gradient, perspective, page edge`
* **Canvas:** 512×512, RGB, no transparency. Grid lines must sit at identical offsets on opposite
  edges (a rule at x = 0 means none at x = 512) so the seam is invisible.
* **Post:** verify with a 3×3 tile test; remove any low-frequency brightness drift (it shows as a
  checkerboard when tiled); snap rules to exact 32 px.

### 4.10 `paper_plain.png` — plain paper (alternative background tile)

**Purpose:** grid-free alternative for wilderness, cut-scenes or a player toggle.

```text
Seamless tileable texture of plain off-white sketchbook paper (#f7f6f0), viewed perfectly flat and
evenly lit, very subtle fibre grain and tooth, no lines at all. Pattern repeats seamlessly on all four
edges. Empty paper only: no drawings, no sprites, no text, no shadows, no vignette, no page edge.
```

* **Negative extras:** `grid, ruled lines, drawing, text, stains, folds, vignette, lighting gradient, page edge`
* **Canvas:** 512×512, RGB, no transparency; same base colour and grain as `paper_grid.png` so the
  two can cross-fade.

### 4.11 `scene_composite.png` — in-game mock-up

**Purpose:** "how the finished game could look"; key art for pitching and for layer QA.

```text
Straight top-down gameplay screenshot of a blue ballpoint sketch game, zoomed in. Squared notebook
paper as the ground. The blacksmith's workshop shown as a cut-away plan with the roof removed:
thick double-line stone walls with dense hatching, plank floor in sparse parallel strokes, a forge
with fire in red ballpoint, bellows, anvil, workbench, tool and weapon racks. The blacksmith at the
anvil, an adventurer with a red cloak at the door, a tree and a fence outside. A hand-drawn red
circle around the adventurer and a red arrow. Bottom of the screen: a hand-drawn blue hotbar with
item slots; top-right a sketched quest card. All objects opaque with pale fills so the grid stops at
their edges; hatched ground shadows to the bottom-right.
```

* **Negative extras:** `perspective, isometric, visible outer walls in elevation, colour fills, legible text, glossy UI`
* **Canvas:** 1920×1080. **Build, don't generate, for production review:** tile `paper_grid.png`
  in world space, place the transparent sprites (≈1.8× zoom), add the interaction prompt
  ("E — Talk", Patrick Hand + red circle) and HUD in Godot. A generated version is only a mood frame.

---

## 5. Keeping consistency for additional assets

**Reference / seed strategy**
* Freeze a *style anchor set*: blacksmith, tree, sword and one building, plus the client's first
  reference image once available. Feed 1–2 of them as style references on every generation.
* Record model, version, seed, sampler, guidance and reference weights per asset in a sidecar
  `.json` next to the master.
* Train a small style LoRA after ~30 approved assets; it is especially effective for pen texture.

**Ink lock** — after generation, separate ink from fill: threshold the pen strokes, recolour them to
exactly `#1f3a93` (red strokes to `#c62828`) keeping anti-aliased alpha, and flood fills with the
README tint for their material. Reject outputs with black, purple or multi-colour pens.

**Tone lock** — compare hatch density per material with the tone table (0–3). Over-hatched skin or
under-hatched boots are the most common drift; fix by masking and re-hatching.

**Light direction** — top-left only. If the dense hatching is on the left, regenerate; never fix by
mirroring an asymmetric character.

**Red budget** — at most one red element per character and per prop; red on terrain is a reject.

**Scale reference sheet** — keep `ref_scale_sheet.png`: blacksmith, adventurer, door, barrel,
anvil, tree on the 32 px grid paper at game scale; check every new asset against it.

**Post-processing checklist**
1. Straight top-down? (no side walls, no faces seen from the front)
2. Transparent background, **no paper or grid baked in**, interior fills opaque, no white matte halo.
3. Only blue `#1f3a93` and red `#c62828` strokes; red within budget.
4. Tone per material matches; double-passed silhouette present; readable at 128 px.
5. Light top-left, hatched ground shadow bottom-right.
6. No generated text, pseudo-handwriting or numbers.
7. Construction lines only on standalone/icon art; none in animation frames.
8. Canvas size, margin and pivot per [`naming_guide.md`](naming_guide.md); file named correctly.

**Fill-in-the-blank template**

```text
[MASTER STYLE PROMPT]
Single [character / prop / building / interior / icon] sprite, [straight top-down view from directly
above, facing south | inventory icon, view: ___]. Subject: [who/what], [build/size relative to the
blacksmith]. Materials and hatch tone: [material -> tone 0/1/2/3, e.g. leather apron tone 2, boots
tone 3]. Holding/featuring [items]. Distinctive detail: [1-2 storytelling details]. Red ballpoint
only for: [gem / magic / fire / one key item / none]. Construction lines: [axis + guide circle |
none]. Hatched ground shadow toward the bottom-right. Opaque very pale fills inside all shapes.
Isolated on a transparent background, no paper, centred, [margin] px margin, canvas [512x512 | other].
Negative: [MASTER NEGATIVE] + [subject-specific exclusions]
```

For a paper or other background tile, do **not** use the master prompt; start from 4.9/4.10 and
always state "seamless tileable, all four edges, no drawings, no sprites, no text".
