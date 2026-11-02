# Prompts — 07 Illustrated Sketchbook Fantasy ("Tales from the Anvil")

These prompts are for producing **production-quality** versions of the style studies in this
folder with an image model, or for briefing an illustrator. The existing PNGs are procedural vector
mock-ups (see `README.md` → *Rendering note*); use them as composition, palette, layering and
framing references (img2img / reference image), not as the quality target.

**Reference images:** this direction is based on the second of two newly supplied reference images,
but **neither image was present in the repository or build session**. The prompts below are written
from the client's written description. Once the references are added (e.g. to
`docs/visual_exploration/references/`), re-check the master prompt — line character, wash
transparency, palette, proportions — against the second image, and consider using it as a style
reference in generation.

Prompt syntax is model-agnostic plain English. Adapt weighting syntax, aspect-ratio flags and seeds
to the tool in use.

**The one rule that differs from the other directions:** sprites and paper are produced
**separately**. Sprite prompts must produce a transparent background with **no paper**; paper prompts
must produce **only paper** — seamless, with no drawings on it.

---

## 1. Master style prompt

Prepend to every sprite, icon and scene prompt (not to the paper prompts in §3.9–3.10):

```text
Illustrated sketchbook fantasy, hand-drawn in a travelling illustrator's sketchbook: expressive
irregular dark sepia-brown ink outlines (#3a2e28), loose and slightly doubled as if drawn quickly
with a dip pen, visible grey graphite pencil hatching in the shadows, subtle transparent watercolour
washes with darker pigment edges, soft granulation and the occasional bloom, flat-ish fills with one
soft shadow wash, muted natural colours (sage, olive, grey-brown, faded terracotta, slate, stone,
linen), occasional vivid magical accents in teal and violet only on magical things, warm orange only
for fire, organic hand-drawn shapes with nothing ruler-straight, friendly and expressive but mature
fantasy characters with grounded adult proportions, soft neutral daylight from the top-left with
shadows to the bottom-right, straight top-down orthographic view looking directly down (unless
stated otherwise).
```

### Master negative prompt

```text
painted gouache, smooth gradients, airbrush, golden hour, polished digital painting, black
outlines, pure black, clean vector lines, uniform line weight, cel shading, engraving, cross-hatching
everywhere, woodcut, manuscript decoration, map border, parchment, pixel art, 3D render, CGI,
glossy, photorealistic, anime, chibi, baby proportions, big cute eyes, neon colours everywhere,
oversaturated, isometric, three-quarter view, perspective camera, side view (for top-down assets),
text, handwriting, watermark, signature, logo, frame border, paper texture background (for sprites),
notebook page, spiral binding, cropped, cut off, blurry, muddy, jpeg artefacts, white halo.
```

---

## 2. Consistent artistic & technical requirements

| Requirement | Value |
|---|---|
| Medium look | Ink line + graphite pencil + transparent watercolour; no gouache opacity, no gradients |
| Line | Irregular, slightly doubled sepia-brown `#3a2e28`; ~2.6 px at 512 px master (≈ 0.65 px at 128 px — **thicken for target size**, see `naming_guide.md`); actors heavier (≈ 1.3–1.5×) than environment |
| Pencil | Grey `#6e6862`, loose diagonal hatching at about −35° in shadows only |
| Washes | Flat-ish, darker pigment rim inside each shape, one soft shadow wash bottom-right; fills **opaque enough to hide what is behind** in sprites |
| Light | Neutral soft daylight from **top-left**; shadows bottom-right |
| Palette | Lock to the ramps in `README.md` → *Colour palette*; teal `#1fb5d6` / violet `#9a5cf0` only on magic; orange only for fire |
| Proportions | Head 1.08×, belly 1.04×, shoulders 1.0× of the shared neutral design; adult anatomy |
| Camera | Characters, props, trees, town: **straight top-down orthographic**. Icons: front/45° presentation |
| Detail floor | Nothing important smaller than ~12 px at 512 px master (≈ 3 px at 128 px game size) |
| Master resolution | Sprites/icons 512×512 (2× or 4× final), scenes 1920×1080 or 3840×2160, paper 512×512 or 1024×1024 |
| Colour space | sRGB, 8-bit, PNG |

### Transparent background & framing rules (sprites and icons)

- **Transparent background, no paper.** RGBA PNG, straight alpha. If the model can't output alpha,
  generate on flat mid-grey `#808080` or flat `#ff00ff` (not on paper, not on white — pale washes
  are hard to key from white/cream), then key out and de-fringe.
- **Fill opacity:** the body of every sprite is fully opaque (alpha 255); the watercolour "transparency"
  is represented by the colour, not by alpha. Only the outer anti-aliased edge, soft shadows and FX
  are semi-transparent.
- Contact shadow: characters and trees include their soft wash shadow (+ a few pencil strokes)
  on the transparent canvas. Icons have **no** ground shadow.
- Subject centred; **≥ 8 % padding** (≈ 40 px at 512); nothing touches the edge.
- Characters: contact point near the canvas centre-bottom so the pivot can sit at `(256, ~304)`
  (= `(64, 76)` at 128 px); same scale on every character canvas (scale sheet, §4).
- No borders, paper edges, page texture, lettering or splashes outside the subject.

---

## 3. Individual prompts

### 3.1 `blacksmith.png` — protagonist sprite

**Purpose:** player character master sprite; identity reference for all rig parts.
**Canvas:** 512×512, transparent, straight top-down, facing south.

```text
[MASTER STYLE PROMPT], game character sprite seen from directly above (straight top-down
orthographic), facing down toward the bottom of the image. An older heavyset retired adventurer who
now runs the village smithy: bald scarred scalp seen from above with a fringe of grey hair at the
back, scars drawn as quick ink marks, a dark leather eyepatch strap crossing the head, a big
grey-white braided beard with a gold beard-ring projecting forward over a large round belly, tanned
leather work apron with a pocket and scorch marks, leather belt with brass buckle, apron straps over
a linen shirt, a single old dented steel pauldron on his left shoulder, leather bracers, a heavy
iron sledgehammer in his right hand (viewer's left), tongs at his left hip, worn boot toes peeking
out, soft brown-grey watercolour contact shadow with a few pencil strokes. Expressive irregular ink
contour slightly heavier than the interior lines, pencil hatching on the bottom-right, kind but
weathered, centred, transparent background, no paper.
```

- **Negative:** master negative + `front view, face visible, eyes, young, bodybuilder, cartoon belly, paper background`.
- **Framing:** shoulders ≈ 65 % of canvas width incl. pauldron (→ ≈ 84 px at 128 px); 40 px padding; hammer head inside canvas.
- **Consistency:** scale anchor. Beard ring and the *single* left pauldron in every direction and frame; hammer always in the right hand.

### 3.2 `adventurer.png` — visiting adventurer

**Purpose:** generic NPC/party member; checks the proportion system on a slimmer build.
**Canvas:** 512×512, transparent, straight top-down, facing south.

```text
[MASTER STYLE PROMPT], game character sprite seen from directly above (straight top-down
orthographic), facing down toward the bottom of the image. A seasoned human adventurer of slimmer
build: round wooden shield with an iron boss slung on the back over a sage-green wool cloak, hair
tied in a ponytail, steel pauldrons on both shoulders, faded red tunic under a brown leather jerkin,
leather bracers, a drawn steel longsword held point-forward in the right hand, a dagger at the left
hip, boot toes peeking out, soft watercolour contact shadow with pencil strokes. Same scale and
proportion system as the blacksmith sprite, heavier ink contour on the silhouette, centred,
transparent background, no paper.
```

- **Negative:** master negative + `face visible, heroic exaggerated shoulders, glowing sword, paper background`.
- **Framing:** same pivot height and padding as 3.1; ~15 % narrower shoulders than the smith.
- **Consistency:** use 3.1 as image reference; the shield must read as the largest shape from above.

### 3.3 `sword.png` — inventory icon

**Purpose:** weapon icon master; template for all weapon icons.
**Canvas:** 512×512, transparent, presentation view.

```text
[MASTER STYLE PROMPT], inventory item icon, a single fantasy longsword lying on a 45-degree diagonal
with the tip pointing to the top-right and the pommel at the bottom-left. Fullered steel blade drawn
with a confident irregular ink contour, pale steel wash with a lifted highlight along the top-left
edge and pencil hatching along the shadow side, curled brass crossguard, a vivid teal magical gem in
the guard with a small soft teal glow bleeding past the ink line, leather-wrapped grip, round
pommel. Centred, fills about 80 percent of the canvas, transparent background, no ground shadow, no
paper.
```

- **Negative:** master negative + `hand holding sword, multiple swords, scabbard, perspective foreshortening, paper background`.
- **Framing:** tip and pommel ~45 px from opposite corners; same diagonal for all one-handed blades.
- **Consistency:** the teal gem is the only saturated colour; non-magical weapons have no teal at all.

### 3.4 `armor.png` — inventory icon

**Purpose:** body-armour icon master; template for armour sets.
**Canvas:** 512×512, transparent, front view.

```text
[MASTER STYLE PROMPT], inventory item icon, a steel plate breastplate seen straight from the front,
empty (no wearer): central ridge, small anvil emblem, gorget at the neck, three-lame pauldrons on
each shoulder, faulds and tassets below the waist, brown leather side straps with brass buckles,
rivets as quick ink dots. Pale grey-blue steel wash with darker pigment rims, pencil hatching on the
right-hand plates, lifted highlights top-left, slightly worn. Symmetrical, centred, transparent
background, no ground shadow, no paper.
```

- **Negative:** master negative + `person wearing armour, mannequin, helmet, chrome, sci-fi, paper background`.
- **Framing:** fills ~80 % height, symmetry axis on x = 256.
- **Consistency:** the anvil emblem is the smith's maker's mark; reuse it on everything he forges.

### 3.5 `tree.png` — environment tree

**Purpose:** top-down canopy master for the forest/village tree set.
**Canvas:** 512×512, transparent, straight top-down.

```text
[MASTER STYLE PROMPT], environment game asset, a broadleaf deciduous tree seen from directly above
(straight top-down orthographic): an organic canopy built from irregular overlapping leaf clusters,
each with a loose broken ink outline and a muted sage-green wash with darker pigment edges,
brightest clusters top-left, pencil hatching in the bottom-right clusters, a few scalloped leaf
marks and pale lifted dapples, trunk and roots just peeking out at the lower edge, soft brown-grey
wash shadow offset to the bottom-right with a few pencil strokes. Transparent background, no paper.
```

- **Negative:** master negative + `side view, visible trunk length, pine tree, palm tree, perfect circle canopy, paper background`.
- **Framing:** canopy ~75 % of canvas; shadow may extend into the bottom-right padding but not touch the edge.
- **Consistency:** variants by wash colour (`foliage` sage / `foliage2` olive) and cluster count; keep the light side; ship the long shadow separately if time-of-day rotates shadows.

### 3.6 `town_view.png` — village overview

**Purpose:** key art / map mood reference; shows the paper-as-ground approach.
**Canvas:** 1920×1080 (or 3840×2160), opaque, straight top-down.

```text
[MASTER STYLE PROMPT], a page from an illustrator's sketchbook showing a small medieval fantasy
village from directly above (straight top-down orthographic, no perspective). The ground is mostly
bare warm cream paper with loose pale green watercolour washes and quick pencil grass marks; roads
are pale earth washes with soft uneven edges; a stream on the east side is a blue-grey wash with a
loose ink bank line and pencil ripples, crossed by a small wooden bridge. A central crossroads
square with a stone well and a market stall. South-west, the blacksmith's workshop with a slate
roof, a chimney with a loose smoke wash and an open forge yard with an anvil and a glowing orange
forge. North-east, the largest building, the L-shaped inn "The Tipsy Wyvern" with a terracotta roof,
a stable and beer-garden tables. Thatched and terracotta cottages, a small stone chapel, fences,
barrels, crates, vegetable patches. Forest edge of loose canopy clusters along the north and west.
Tiny villagers seen from above, the heavyset bearded blacksmith at his anvil, an adventurer with a
round shield walking toward the inn. Muted natural colours, with only a few small teal and violet
magical sparkles (over the square, near the chapel and by the smithy) as vivid accents.
```

- **Negative:** master negative (without `paper texture background`) + `isometric, building facades, tilted camera, readable text, opaque painted terrain, notebook lines`.
- **Framing:** square near the image centre; smithy lower-left of centre; inn upper-right; stream right third; forest top and left.
- **Consistency:** in production this is assembled from layers (paper + washes + sprites); generate only as a mood target. Place-name labels ("Brindlewick", "The Tipsy Wyvern", …) are set in engine in Amatic SC / Shantell Sans, never generated.

### 3.7 `menu_screen.png` — main menu

**Purpose:** title screen; defines the UI kit (paper panels, hand-drawn buttons) and title lettering.
**Canvas:** 1920×1080, opaque.

```text
[MASTER STYLE PROMPT], video game main menu designed as an open sketchbook spread on warm cream
paper: loose watercolour splashes in sage, ochre and a little teal and violet behind the title area,
ink-and-wash drawings of the heavyset bearded blacksmith at his anvil and an adventurer with a round
shield, a sketched village corner fading out into bare paper. Title lettering "Tales from the Anvil"
in a calligraphic hand-lettered fantasy style in sepia ink with a small flourish. A vertical list
of hand-drawn buttons — loose ink rectangles with wobbly corners and a pale wash fill: "Continue",
"New Game", "Load Game", "Settings", "Credits", "Quit"; the hovered button has a teal wash and an
extra ink stroke. Small version label bottom-right.
```

- **Negative:** master negative (without `text` and `paper texture background`) + `misspelled text, extra buttons, glossy buttons, sci-fi UI, spiral binding, ruled notebook lines`.
- **Framing:** buttons on the left or right third; characters on the opposite side; title top.
- **Consistency:** generate background art and splashes only; set all text in engine (Fondamento title, Shantell Sans buttons). Build buttons as 9-slice ink frames over the paper layer.

### 3.8 `font_reference.png` — typography sheet

**Purpose:** visual QA of the type system; not a generation target in production.
**Canvas:** 1920×1080, opaque, paper background with one dark tooltip panel.

```text
[MASTER STYLE PROMPT], clean typography specimen page in a sketchbook on warm cream paper: the title
"Tales from the Anvil" in a calligraphic fantasy hand in sepia ink; headings in tall hand-lettered
capitals; UI text and dialogue in an informal hand-drawn sans; four hand-drawn button states (normal,
hover with teal wash, pressed darker, disabled faded pencil); item names in ink-dark rarity colours
on the paper and in light rarity colours on a dark ink-brown tooltip panel; a stats block with aligned
numbers; small watercolour swatches of the palette.
```

- **Negative:** master negative + `random glyphs, lorem ipsum gibberish, misspelling`.
- **Note:** build this sheet in Godot or a layout tool with the real fonts (Fondamento, Amatic SC,
  Shantell Sans); the prompt is only for decoration and mood.

### 3.9 `paper_plain.png` — primary background paper (tileable)

**Purpose:** the world's ground and the UI's page; tiled in world space under all sprites.
**Canvas:** 512×512 (or 1024×1024), opaque, **seamlessly tileable**. Do **not** prepend the master prompt.

```text
Seamless tileable texture of warm cream sketchbook drawing paper, average colour around #f1e6cf,
lit flat and evenly, seen straight on: subtle cold-press watercolour paper tooth, very fine fibres,
faint irregular mottling, extremely low contrast, no visible repeat features, no stains, no folds,
no edges, no shadows, no vignette, no drawings, no lines, no text, nothing on the paper. Edges wrap
perfectly left-right and top-bottom.
```

- **Negative:** `drawings, sketches, sprites, ink, pencil marks, grid, ruled lines, notebook, spiral binding, stains, coffee rings, torn edge, folds, vignette, lighting gradient, perspective, parchment, aged yellowing, high contrast noise, recognisable blotches, text, watermark`.
- **Post:** make seamless (offset 50 % and heal seams, or use the model's tiling mode); check by
  tiling 3×3 — no blotch may be recognisable as repeating. Keep luminance variation within roughly
  ±3 % so ink and washes always dominate. Colour-correct the average to ≈ `#f1e6cf`.

### 3.10 `paper_grid.png` — optional squared paper (tileable)

**Purpose:** alternative page for crafting, blueprint and inventory screens. Optional for the world.
**Canvas:** 512×512, opaque, **seamlessly tileable**; grid pitch must divide 512 exactly
(e.g. 32 px → 16 squares, or 64 px with 16 px minor lines).

```text
Seamless tileable texture of warm cream squared sketchbook paper, same paper tone and fine tooth as
plain cream drawing paper (around #f1e6cf), with a thin, slightly faded printed grid in soft
grey-blue, perfectly regular spacing, lines evenly faint, lit flat and evenly, no drawings, no
handwriting, no text, no margin line, no holes, no edges, no shadows. Edges wrap perfectly.
```

- **Negative:** as 3.9, minus `grid, ruled lines`; plus `uneven grid, perspective grid, thick lines, red margin, punched holes`.
- **Post:** the grid must line up across tile edges at pixel level; verify by tiling 3×3. Grid lines at
  low contrast (≈ 10–15 % darker than the paper) so sprites remain dominant.

### 3.11 `scene_composite.png` — layered gameplay mock-up

**Purpose:** proves the layer architecture: transparent sprite/environment layers over tiled paper at
gameplay zoom, with an interior and HUD.
**Canvas:** 1920×1080, opaque (composited).

```text
[MASTER STYLE PROMPT], gameplay screenshot mock-up at close zoom (about 1.8x), straight top-down
orthographic, on bare warm cream sketchbook paper. The blacksmith's workshop with its roof removed to
reveal the interior: stone walls drawn as thick ink-outlined bands, a plank floor in pale wood wash,
the forge with a glowing orange fire, bellows, the anvil, a workbench with tools, weapon and armour
racks. The heavyset bearded smith at the anvil, an adventurer with a round shield entering through
the door, a hand-drawn interaction prompt bubble near the anvil. Outside, pale grass washes with
pencil marks, a tree, barrels. Game HUD drawn as ink-and-wash elements on paper: a hotbar of item
slots along the bottom and a small quest card in the corner.
```

- **Negative:** master negative (without `paper texture background` and `text`) + `isometric, roof visible over the interior, walls seen from the side, glossy UI, misspelled text`.
- **Consistency:** in production this image is *assembled*, not generated: paper layer + wash tiles +
  sprites + interior tiles + UI scenes. Use the prompt only to explore interior dressing; any text
  (prompt key, quest text, numbers) is set in engine.

---

## 4. Keeping consistency when generating additional assets

### Reference-image & seed strategy

1. Approve a **style anchor set**: blacksmith, adventurer, sword, tree, one roof, one rock cluster,
   `paper_plain`. Store in `art_source/anchors/`. Add the client's second reference image here once
   it is supplied.
2. Generate every new asset with **one anchor of the same category as image reference**
   (weight ~0.4–0.6) plus the master prompt. Train a style LoRA once 20–30 approved assets exist —
   on transparent sprites **composited over flat grey, not over paper**, or the model learns to
   bake paper in.
3. Fix a **seed per category** (characters 7101, icons 7201, props 7301, buildings 7401, paper 7501)
   and log seed, model, sampler and reference in the asset's sidecar `.txt`.
4. Directions and rig parts: img2img from the approved master at low denoise (0.25–0.4).

### Line & wash lock

- **Line is the identity.** After generation, redraw or clean up the outer contour by hand in
  `#3a2e28` at target thickness; models tend to produce lines that are either too clean or too
  scratchy. Keep interior lines lighter than the contour.
- Gradient-map washes to the palette ramps; check that natural materials stay muted and that teal,
  violet and orange appear only on magic and fire.
- Remove any paper texture, page edge or vignette the model adds; grain comes from the in-engine
  paper overlay.
- Maintain `palette_sketchbook.ase` / `.gpl` with all ramps from `README.md`.

### Light direction

- Top-left for everything; pencil hatching in the bottom-right shadow at about −35°. Reject outputs
  with centred or side lighting. Mirrored assets need their hatching and shadow redrawn.

### Scale reference sheet

Keep `art_source/scale_sheet.png` on a 64 px grid **over `paper_plain.png`**: smith, adventurer,
villager, door, barrel, rock, cottage roof, tree, anvil. Every new sprite is placed on it before
approval (this also tests contrast against the page).

### Post-processing checklist

- [ ] Background removed; **no paper** in the sprite; alpha edges de-fringed (no cream/white halo)
- [ ] Sprite body fully opaque; only edges, shadows and FX semi-transparent
- [ ] Straight (non-premultiplied) alpha PNG, sRGB
- [ ] Ink line `#3a2e28`, not black; actor contour heavier than environment; thickened for target size
- [ ] Palette muted; accents only on magic/fire
- [ ] Light top-left, pencil hatch bottom-right; contact shadow present (characters/trees) or absent (icons)
- [ ] Padding ≥ 8 %; pivot per `naming_guide.md`
- [ ] Downsampled once from master; checked at 1× zoom over `paper_plain.png` and over a dark tooltip
- [ ] Paper textures: seamless at 3×3, flat lighting, no drawings
- [ ] No text, signature or artefacts; filename per `naming_guide.md`; sidecar `.txt`

### Fill-in-the-blank template

```text
[MASTER STYLE PROMPT], {ASSET TYPE: game character sprite | inventory item icon | environment prop |
building roof | rock cluster | ui element}, seen {straight top-down orthographic, facing down |
front view | 45-degree diagonal, tip top-right}. {SUBJECT: who/what}, {KEY MATERIALS as muted washes:
e.g. grey-brown leather, pale steel, sage wool}, {DISTINGUISHING DETAILS: 3-5 items readable from this
angle, drawn as expressive ink marks}, {STORY DETAIL: wear, scorch, repair, age},
{MAGIC ACCENT: none | teal glow on … | violet glow on …}. Irregular sepia ink contour
{heavier for actors | standard for environment}, pencil hatching bottom-right, top-left light,
{contact shadow: soft wash contact shadow with pencil strokes | no ground shadow}, centred with
padding, transparent background, no paper. Same scale as {REFERENCE ANCHOR}.
Negative: [MASTER NEGATIVE], {asset-specific exclusions}.
```

For new paper textures, use the template of §3.9 instead and never prepend the master prompt.
