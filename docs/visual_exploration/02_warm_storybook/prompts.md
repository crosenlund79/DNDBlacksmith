# Prompts — 02 Warm Storybook Village ("The Old Anvil")

These prompts are for producing **production-quality** versions of the eight style studies in
this folder with an image model, or for briefing an illustrator. The existing PNGs are
procedural vector mock-ups (see `README.md` → *Rendering note*); use them as composition,
palette and framing references (img2img / reference image), not as the quality target.

No reference images were present in the repository. If the four reference images mentioned in
the brief are supplied, re-check the master prompt, palette and proportions against them
before batch generation.

Prompt syntax is model-agnostic plain English. Weighting syntax, `--ar`, seeds etc. should be
adapted to the tool in use.

---

## 1. Master style prompt

Prepend to every prompt (or store as a style preset):

```text
Warm storybook fantasy illustration, hand-painted gouache and watercolour on textured paper,
mature classic fairy-tale book illustration for adults, soft painterly edges, no black
outlines, thin soft coloured edge lines in each material's own darker shade, rich natural
materials (worn leather, oiled wood, forged steel, linen, stone, thatch), gently rounded
shapes with grounded believable anatomy, warm golden late-afternoon key light from the
top-left, soft warm umber shadows falling to the bottom-right, three-tone painted volumes
(creamy lights, saturated mid-tones, earthy red-brown shadows), subtle paper grain and
pigment granulation, slight hand-drawn wobble, dappled sunlight on foliage, cosy lived-in
medieval fantasy village atmosphere with hints of age and mystery, straight top-down
orthographic view looking directly down (unless stated otherwise), cohesive limited palette
of ochre, honey gold, moss green, terracotta, warm stone and madder red.
```

### Master negative prompt

```text
black outlines, thick ink lines, cel shading, hard shadow bands, vector flat design, pixel
art, 3D render, CGI, plastic, glossy, photorealistic, anime, chibi, childish cartoon, baby
proportions, big cute eyes, neon colours, oversaturated, cold blue shadows, grey shadows,
pure black, harsh rim light, lens flare, bloom haze, isometric, three-quarter view,
perspective camera, side view (for top-down assets), text, watermark, signature, logo,
frame border (for sprites), cropped, cut off, blurry, muddy, jpeg artefacts, noisy
background, drop shadow on transparent background edges, white halo.
```

---

## 2. Consistent artistic & technical requirements

| Requirement | Value |
|---|---|
| Medium look | Gouache + watercolour, visible paper tooth, no digital airbrush gradients |
| Edges | Soft painted; coloured line in local shadow hue (~2 px at 512 px); no black |
| Light | Single warm key from **top-left**, soft; shadows bottom-right |
| Shadow colour | Warm umber/red-brown (`#4a2e14`–`#5a3218`), never grey/black/blue (except water, gems) |
| Palette | Lock to the ramps in `README.md` → *Colour palette*; accents only on focal items |
| Proportions | Head 1.04×, belly 1.04×, shoulders 1.0× of neutral; grounded adult anatomy |
| Camera | Characters, props, trees, town: **straight top-down orthographic**. Icons: front/45° presentation |
| Detail floor | Nothing important smaller than ~12 px at 512 px master (≈ 3 px at 128 px game size) |
| Master resolution | Sprites/icons 512×512 (2× or 4× final), scenes 1920×1080 or 3840×2160 |
| Colour space | sRGB, 8-bit, PNG |

### Transparent background & framing rules

- Sprites and icons: **transparent background** (RGBA PNG, straight alpha). If the model can't
  output alpha, generate on flat `#ff00ff` or flat mid-grey `#808080` with no shadow on the
  background, then key out and **de-fringe** (see checklist).
- Contact shadow: characters and trees *include* their soft warm ground shadow on the
  transparent canvas (semi-transparent `#4a2e14`). Icons have **no** ground shadow.
- Subject centred; **≥ 8 % padding** on every side (≈ 40 px at 512); nothing touches the edge.
- Characters: feet/contact point at the canvas centre-bottom area so the pivot can sit at
  `(256, ~304)` (= `(64, 76)` at 128 px); same scale on every character canvas (see scale sheet, §5).
- No borders, vignettes, paper edges or text in sprites.

---

## 3. Individual prompts for the eight examples

### 3.1 `blacksmith.png` — protagonist sprite

**Purpose:** player character master sprite; identity reference for all animation parts.
**Canvas:** 512×512, transparent, straight top-down, facing south (toward the bottom of the image).

```text
[MASTER STYLE PROMPT], game character sprite seen from directly above (straight top-down
orthographic), facing down toward the bottom of the image. An older heavyset retired
adventurer who now runs the village blacksmith: bald scarred scalp seen from above with a
fringe of grey hair at the back, a dark leather eyepatch strap crossing the head, a big
grey-white braided beard with a gold beard-ring projecting forward over a large round belly,
tanned leather work apron with a front pocket and scorch marks, leather belt with brass
buckle and pouch, apron straps crossing over a linen shirt on his back, a single old dented
steel adventuring pauldron on his left shoulder, leather bracers, bare hairy forearms, a
heavy iron sledgehammer hanging from his right hand (on the viewer's left), blacksmith
tongs hooked at his left hip, toes of worn boots peeking out below the belly, soft warm
blurred contact shadow under him. Warm top-left light, gouache texture, kind but weathered,
strong silhouette, centred, transparent background.
```

- **Negative:** master negative + `front view, face visible, eyes, standing pose seen from the side, young, muscular bodybuilder, cartoon belly`.
- **Framing:** body centred; shoulders ≈ 65 % of canvas width incl. pauldron (→ ≈ 84 px at the 128 px game size); 40 px padding; hammer head inside canvas.
- **Consistency:** this is the scale anchor. Beard ring and the *single* left pauldron must appear in every direction and frame; hammer always in the right hand.

### 3.2 `adventurer.png` — visiting adventurer

**Purpose:** generic NPC/party member; checks the proportion system on a slimmer build.
**Canvas:** 512×512, transparent, straight top-down, facing south.

```text
[MASTER STYLE PROMPT], game character sprite seen from directly above (straight top-down
orthographic), facing down toward the bottom of the image. A seasoned human adventurer of
slimmer build: round wooden shield with an iron boss slung on the back over a moss-green
wool cloak, hair tied in a ponytail with a cloth headband, steel pauldrons on both
shoulders, madder-red tunic under a brown leather jerkin, leather bracers, a drawn steel
longsword held point-forward in the right hand, a dagger at the left hip, worn boots
peeking out, soft warm contact shadow. Same scale and proportion system as the village
blacksmith sprite, warm top-left light, centred, transparent background.
```

- **Negative:** master negative + `face visible, heroic exaggerated shoulders, armour bikini, glowing sword`.
- **Framing:** same pivot height and padding as 3.1; ~15 % narrower shoulders than the smith.
- **Consistency:** generate with 3.1 as reference image; shield must read as the largest shape from above.

### 3.3 `sword.png` — inventory icon

**Purpose:** weapon icon master; template for all weapon icons.
**Canvas:** 512×512, transparent, presentation view.

```text
[MASTER STYLE PROMPT], inventory item icon, a single fantasy longsword shown flat on a
45-degree diagonal with the tip pointing to the top-right and the pommel at the
bottom-left. Fullered steel blade with faintly glowing engraved runes, curled gold
crossguard with a central sapphire gem, dark leather-wrapped grip with brass bands, round
gem pommel. Soft painted volume, warm top-left highlight along the blade edge, coloured soft
edge lines, centred, fills about 80 percent of the canvas, transparent background, no ground
shadow.
```

- **Negative:** master negative + `hand holding sword, multiple swords, background, scabbard, perspective foreshortening`.
- **Framing:** tip and pommel ~45 px from opposite corners; identical diagonal for all one-handed blades.
- **Consistency:** every weapon icon uses the same 45° and light; gem colours follow the gem ramp unless the item's element dictates otherwise.

### 3.4 `armor.png` — inventory icon

**Purpose:** body-armour icon master; template for armour sets.
**Canvas:** 512×512, transparent, front view.

```text
[MASTER STYLE PROMPT], inventory item icon, a steel plate cuirass seen straight from the
front, empty (no wearer): breastplate with a central ridge and a small gold anvil emblem,
gorget at the neck, three-lame pauldrons on each shoulder, faulds and tassets below the
waist, brown leather side straps with brass buckles, rows of rivets. Warm top-left light,
soft painted steel with creamy highlights and warm brown-grey shadows, slightly worn and
lived-in, symmetrical, centred, transparent background, no ground shadow.
```

- **Negative:** master negative + `person wearing armour, mannequin, helmet, chrome, sci-fi`.
- **Framing:** fills ~80 % height, centred; symmetrical axis on x = 256.
- **Consistency:** the anvil emblem is the protagonist's maker's mark — reuse on all items he forges.

### 3.5 `tree.png` — environment tree

**Purpose:** top-down canopy master for the forest/village tree set.
**Canvas:** 512×512, transparent, straight top-down.

```text
[MASTER STYLE PROMPT], environment game asset, a broadleaf deciduous tree seen from
directly above (straight top-down orthographic): a rounded canopy built from overlapping
soft leaf clusters, brightest clusters on the top-left catching sunlight, darker clusters
on the bottom-right, scattered dappled sunlight spots and small scalloped leaf marks, a hint
of trunk and roots peeking out at the lower edge, soft warm translucent cast shadow offset to
the bottom-right. No outlines on the leaf clusters, gouache texture, transparent background.
```

- **Negative:** master negative + `side view, visible trunk length, pine tree, palm tree, isometric, flowers everywhere`.
- **Framing:** canopy ~75 % of canvas; shadow may extend to the bottom-right padding but not touch the edge.
- **Consistency:** variants by palette swap (`foliage` green / `foliage2` autumn olive) and cluster count; keep the same light side.

### 3.6 `town_view.png` — village overview

**Purpose:** key art / map mood reference; establishes layout and environment density.
**Canvas:** 1920×1080 (generate at 3840×2160 if possible), opaque, straight top-down.

```text
[MASTER STYLE PROMPT], wide game map illustration of a small medieval fantasy village seen
from directly above (straight top-down orthographic, no perspective), golden late-afternoon
light with long soft warm shadows falling to the bottom-right. A central crossroads square of
packed earth with a stone well and a striped market stall. South-west of the square the
blacksmith's workshop: stone walls, slate roof, chimney with drifting smoke, an open forge
yard with an anvil, a glowing forge, a quench trough and a weapon rack. North-east the
largest building, the inn "The Tipsy Wyvern", L-shaped with a clay-tile roof, a stable and
beer-garden tables. Thatched and clay-tile cottages, a small stone chapel, wooden fences,
crates and barrels, flower beds, vegetable patches. A stream with a wooden bridge on the east
side. Forest edge of dense tree canopies along the north and west. Tiny villagers seen from
above, the heavyset bearded blacksmith at his forge and an adventurer with a round shield
walking toward the inn. Cosy, lived-in, gentle mystery in the deep forest shadows.
```

- **Negative:** master negative + `isometric, building facades, walls visible from the side, tilted camera, readable text on signs, modern objects`.
- **Framing:** square at roughly the image centre; workshop lower-left of centre; inn upper-right; stream right third; forest top and left edges.
- **Consistency:** roofs dominate building reads; ground paths lightest, grass mid, forest darkest; characters ≤ 2 % of frame height but with contact shadows.

### 3.7 `menu_screen.png` — main menu

**Purpose:** title screen; defines the UI kit (wood + parchment) and title lettering.
**Canvas:** 1920×1080, opaque.

```text
[MASTER STYLE PROMPT], video game main menu screen. Background: the painted top-down village
in golden late-afternoon light, slightly softened and darkened toward the edges. Title
lettering "The Old Anvil" in a rounded uncial book-hand, warm cream fill, brown outline and
soft drop shadow, top centre-left, with a small anvil-and-hammer emblem. A warm dark-wood
panel with inset parchment and brass corner fittings holding a vertical button list:
"Continue", "New Game", "Load Game", "Settings", "Credits", "Quit"; the hovered button glows
softly amber. Small version label "v0.1.0" bottom-right. Cosy, inviting, storybook cover feel.
```

- **Negative:** master negative + `misspelled text, extra buttons, sci-fi UI, glossy glass buttons, cluttered HUD`.
- **Framing:** UI panel on the left or right third, never covering the forge/inn focal point.
- **Consistency:** generate the background and lettering separately; set final text in-engine with the fonts from `README.md` (image models misspell). Use the generated panel only as a texture reference for 9-slice UI pieces.

### 3.8 `font_reference.png` — typography sheet

**Purpose:** visual QA of the type system; not a generation target in production.
**Canvas:** 1920×1080, opaque, dark wood `#2c2016` with a parchment panel.

```text
[MASTER STYLE PROMPT], clean typography specimen sheet for a fantasy game UI on a dark
warm wood background with one parchment panel: the title "The Old Anvil" in a rounded uncial
with cream fill and brown outline; section headings in a calligraphic serif; UI text in a
rounded sans; a dialogue box with a speaker name and italic narration; four button states
(normal, hover glowing amber, pressed darker, disabled faded); item names in rarity colours
(white-cream, blue, yellow, orange, gold-brown, green); a stats block with aligned numbers.
```

- **Negative:** master negative + `random glyphs, lorem ipsum gibberish, misspelling`.
- **Note:** build this sheet in Godot or a layout tool with the real fonts (Uncial Antiqua,
  Alegreya, Nunito). The prompt is only for mood/frame decoration.

---

## 4. Keeping consistency when generating additional assets

### Reference-image & seed strategy

1. Approve a **style anchor set**: blacksmith, adventurer, sword, tree, one building. Store
   them in `art_source/anchors/`.
2. Generate every new asset with **one anchor of the same category as image reference**
   (strength/weight ~0.4–0.6) plus the master prompt. Use a style LoRA/fine-tune once 20–30
   approved assets exist.
3. Fix a **seed per category** (e.g. characters 4101, icons 4201, props 4301, buildings 4401)
   and log seed, model version, sampler and reference in the asset's sidecar `.txt`.
4. For animation parts or directions, img2img from the approved master at low denoise
   (0.25–0.4) rather than generating from scratch.

### Palette lock

- After generation, **colour-map to the palette ramps** (gradient map or palette-quantise
  per material in the paint tool, then repaint transitions). Check shadows are warm.
- Maintain `palette_storybook.ase` / `.gpl` with all ramps from `README.md`.

### Brush & texture consistency

- Final paint-over by hand with one agreed brush set (gouache flat, round soft, dry-brush
  texture, granulation stamp).
- Apply the **shared paper-grain overlay** (one tileable 1024 px texture, multiply ~10–15 %)
  at export, not per asset.

### Light direction

- Warm key from **top-left** for everything; form shadow bottom-right. Reject any output with
  side or overhead-centred lighting. Flip test: if an asset needs mirroring, re-light it.

### Scale reference sheet

Keep `art_source/scale_sheet.png` showing on one 64 px grid (at 1× game scale): the smith,
the adventurer, a villager, a door, a barrel, a cottage, a tree and the anvil. Every new
sprite is placed on this sheet before approval.

### Post-processing checklist

- [ ] Background removed; alpha edges **de-fringed** (no white/magenta halo; colour
      decontaminate soft edges)
- [ ] Straight (non-premultiplied) alpha PNG, sRGB
- [ ] Palette checked; shadows warm; accents only on focal points
- [ ] Light from top-left; contact shadow present (characters/trees) or absent (icons)
- [ ] Padding ≥ 8 %; subject centred / pivot point per `naming_guide.md`
- [ ] Downsampled once from master (Lanczos/bicubic sharper) to game size; checked at 1× zoom
      on a painted grass tile
- [ ] Silhouette readable when filled flat dark
- [ ] No text, signature or artefacts; filename per `naming_guide.md`
- [ ] Sidecar `.txt` with prompt, seed, model, reference used

### Fill-in-the-blank template

```text
[MASTER STYLE PROMPT], {ASSET TYPE: game character sprite | inventory item icon |
environment prop | building roof | ui element}, seen {straight top-down orthographic,
facing down | front view | 45-degree diagonal, tip top-right}. {SUBJECT: who/what},
{KEY MATERIALS from palette: e.g. worn leather, forged steel, oiled oak}, {DISTINGUISHING
DETAILS: 3-5 items readable from this angle}, {STORY DETAIL: wear, scorch, repair, age}.
Warm top-left light, soft warm shadows to the bottom-right, coloured soft edge lines, gouache
texture, {contact shadow: soft warm contact shadow | no ground shadow}, centred with padding,
transparent background. Same scale as {REFERENCE ANCHOR}.
Negative: [MASTER NEGATIVE], {asset-specific exclusions}.
```
