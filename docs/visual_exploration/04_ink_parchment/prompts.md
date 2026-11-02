# Prompts — 04 Ink-and-Parchment Fantasy · "The Smith's Chronicle"

Prompts for producing production-quality versions of the eight examples (and new assets) with an
image model, or for briefing an illustrator. The example PNGs in this folder are procedural SVG
style studies (see [README](README.md#rendering-note-read-first)); use them as composition and
palette references, not as quality targets.

No reference images were found in the repository (the brief mentioned four). If they are supplied
later, re-check palette, proportions and the master prompt against them and add them as image
references.

---

## 1. Master style prompt

Prefix every asset prompt with this block (adapt syntax to the model: weights, `--no`, etc.).

```text
Ink-and-parchment fantasy illustration in the style of an engraved medieval manuscript and a
hand-drawn campaign map. Sepia iron-gall ink linework (#2b1d12), confident hand-inked contours with
very slight natural wobble, thinner interior detail lines. Shading built from fine diagonal hatching
at -35 degrees and cross-hatching at +35 degrees on the shadow side, no solid black fills, no
airbrushed gradients. Pale, low-saturation watercolour washes as fill colours (muted ochre, faded
red-brown, grey-blue, sage green), highlights left as unpainted paper. Light from the top-left,
shadows fall to the bottom-right. Restrained palette, rubric red (#a8321e) used only as a small
accent. Naturalistic proportions. Straight top-down orthographic view looking directly down
(we see tops of heads, shoulders, roofs and tree canopies), no perspective, no 3/4 angle.
Crisp, clean, game-asset quality, consistent line weight.
```

### Master negative prompt

```text
3/4 view, isometric, perspective, side view, horizon, photorealistic, 3D render, CGI, glossy,
airbrush, smooth gradients, heavy saturation, neon, black fills, pure black shadows, thick cartoon
outlines, cel shading, chibi, big head, anime, pixel art, blurry, painterly oil, watercolour bleeding
outside lines, text, letters, watermark, signature, frame, border (unless requested), parchment
background on sprites, drop shadow glow, lens flare, bokeh, modern objects
```

---

## 2. Consistent artistic & technical requirements

| Item | Lock |
|---|---|
| Camera | Straight top-down orthographic (except icons: icon-specific views below) |
| Light | Top-left; form shadow bottom-right; cast shadow toward bottom-right |
| Ink | `#2b1d12`, outline 2.4 px at 512 px master; actors' outer contour ~1.5× (≈ 3.6 px) |
| Hatch | −35° single hatch, +35° cross-hatch, pitch ~5 px, line ~1.1 px at 512 px |
| Fill | Pale washes from the README palette (light/base/shadow per material); no fill darker than the *shadow* value |
| Accent | Rubric `#a8321e`, gold `#c69c44`, forge glow `#c8641e` — small areas only |
| Ground shadow | Hatched ellipse, never a blurred dark blob |
| Proportions | Naturalistic (head 0.98×, shoulders 1.0×, belly 1.0× of base geometry) |
| Background | Sprites: transparent. Compositions (map, menu, type sheet): parchment `#e9d8b0` |
| Text | Never let the model letter text; add all labels/titles in post or in Godot |

---

## 3. Transparent background & framing rules

* Sprites and icons are **ink + wash on transparency**. The parchment is supplied by the game's
  background tiles and the paper-texture shader; **never bake parchment, paper grain or a vignette
  into a sprite**. If the model cannot output alpha, generate on flat pure white `#ffffff`, then
  key out the white with a soft threshold and *keep* semi-transparent ink edges (straight alpha).
* 512×512 master canvas, subject centred horizontally, ≥ 24 px empty margin on every side.
* Characters: feet/boots at ≈ y 410, hatched ground shadow beneath, facing south (down the screen).
* Nothing touching the canvas edge; no cropped weapon tips.
* Compositions are 1920×1080, 16:9, no transparency.

---

## 4. Individual prompts

Each prompt = **Master style prompt + the text below**. Negative = master negative + extras listed.

### 4.1 `blacksmith.png` — protagonist

**Purpose:** player character sprite master; defines scale and proportions for all actors.

```text
Single character sprite, straight top-down view from directly above, facing south (down the image).
An older, heavyset, experienced retired adventurer who is now the village blacksmith. Bald scarred
scalp seen from above with a fringe of grey hair at the back, a leather eyepatch strap crossing the
head diagonally. Big grey braided beard with a gold beard-ring, projecting forward over a large belly.
Leather apron with a front pocket and scorch marks, belt with brass buckle and a pouch, apron straps
crossing on his broad back. A single old dented steel adventuring pauldron on his left shoulder.
Leather bracers, bare hairy forearms. A heavy sledgehammer hanging from his right hand (on the
viewer's left), iron tongs hanging at his left hip. Boot toes peeking out below the belly.
Hatched elliptical ground shadow under him toward the bottom-right. Isolated on transparent
background, centred, full figure within the frame.
```

* **Negative extras:** `face visible from front, eyes looking at viewer, two pauldrons, helmet, hair on top of head, thin body`
* **Canvas:** 512×512, transparent, feet centre at (256, ~410), ≥ 24 px margin.
* **Consistency:** this is the scale reference — save the seed and use it as image reference for
  every other character. Pauldron on *his* left (viewer's right), hammer viewer's left.

### 4.2 `adventurer.png` — visiting adventurer

**Purpose:** generic NPC/party member; checks that the scale system works for a slimmer body.

```text
Single character sprite, straight top-down view from directly above, facing south. A younger,
slimmer adventurer at the same scale as the blacksmith. Round wooden shield with a metal boss slung
on the back over a muted red cloak; hair tied in a ponytail with a cloth headband; steel pauldrons
on both shoulders; leather jerkin and bracers; drawn sword held point-forward in the right hand;
dagger at the left hip; boots. Hatched elliptical ground shadow toward the bottom-right. Isolated on
transparent background, centred.
```

* **Negative extras:** `bulky, heavyset, helmet covering head, bow, magic effects`
* **Canvas:** 512×512, transparent, feet centre at (256, ~410).
* **Consistency:** shoulder width ≈ 85 % of the blacksmith's; same line weight and hatch angle;
  cloak uses palette `cloak` (`#a2503c`), tunic grey-blue (`#6a7a92`).

### 4.3 `sword.png` — inventory icon

**Purpose:** item icon master (downscaled to 128×128).

```text
Inventory icon of a single longsword lying diagonally at 45 degrees, tip pointing to the top-right,
pommel bottom-left. Steel blade with a central fuller engraved with small runes, curled gold
crossguard with a central red gem, leather-wrapped grip with criss-cross binding, round gem pommel.
Engraved ink linework, hatched shadow along the lower-right edge of the blade, pale steel wash with
a narrow unpainted highlight. Isolated on transparent background, centred, filling about 80 % of
the frame.
```

* **Negative extras:** `hand holding sword, scabbard, glow, sparkles, multiple swords, blood`
* **Canvas:** 512×512, transparent, centred, ≥ 32 px margin.
* **Consistency:** all weapon icons use the same 45° diagonal, tip top-right.

### 4.4 `armor.png` — inventory icon

**Purpose:** armour icon master; shows decorative restraint on equipment.

```text
Inventory icon of a plate armour set seen from the front, no wearer: breastplate with a central
ridge and a small gold anvil emblem, gorget at the neck, three-lame pauldrons on both shoulders,
faulds below the waist, two tassets, leather side straps with buckles, visible rivets. Engraved
ink linework, -35 degree hatching on the right-hand sides of each plate, pale steel wash, gold
emblem in muted gold. Isolated on transparent background, centred, symmetrical.
```

* **Negative extras:** `person wearing it, helmet, arms, legs, mannequin, stand, glow`
* **Canvas:** 512×512, transparent, centred, ≥ 32 px margin.
* **Consistency:** armour icons are always front view, symmetric, lit from top-left.

### 4.5 `tree.png` — environment

**Purpose:** canopy sprite master for forests and the village.

```text
Single deciduous tree seen straight from above as on a hand-drawn map: a rounded canopy made of
overlapping foliage clusters, each cluster outlined with scalloped leaf marks, sage-green washes in
two tones, hatched shadow on the lower-right side of each cluster, the base of the trunk just
peeking out at the bottom. Hatched cast shadow falling toward the bottom-right. Isolated on
transparent background, centred.
```

* **Negative extras:** `side view of trunk, roots, side-view tree, pine, flowers, fruit`
* **Canvas:** 512×512, transparent; anchor = trunk base at canvas centre-bottom area.
* **Consistency:** use foliage (`#909c6c`) and foliage2 (`#a49c62`) washes; 3–4 variants per species.

### 4.6 `town_view.png` — village as illustrated map

**Purpose:** key art for the world view and proof of top-down fit.

```text
Straight top-down view of a small medieval fantasy village drawn as a hand-illustrated map on aged
parchment. Central crossroads square with a stone well and a market stall. South-west of the square
the blacksmith's workshop: stone walls, grey slate roof, chimney, open forge yard with anvil, forge,
quench trough and weapon rack. North-east the inn, the largest building, L-shaped with a tiled roof,
a stable and beer-garden tables. Several cottages, a small chapel, wooden fences, crates and barrels.
A stream with a wooden bridge on the east side. Forest edge to the north and west drawn as massed
scalloped canopies. Tiny figures in the streets. Ornamental double-rule border with corner fleurons,
a compass rose in a corner, empty cartouches for labels. Ink linework with hatched shadows to the
bottom-right, pale watercolour washes, rubric red accents.
```

* **Negative extras:** `perspective, isometric buildings, side walls visible, legible text, modern map symbols, grid`
* **Canvas:** 1920×1080, parchment background, no transparency.
* **Post:** add labels in post — "The Tipsy Wyvern", "The Smithy", "Chapel", "Market Square" — in
  IM Fell English italic, ink with rubric initial.
* **Consistency:** buildings at 64 px/tile scale relative to characters (inn ≈ 6×4 tiles, smithy
  ≈ 4×3 tiles including yard).

### 4.7 `menu_screen.png` — main menu

**Purpose:** UI key art; establishes the "chronicle" framing.

```text
An open illuminated chronicle lying flat, seen from directly above, filling the frame on a dark
wooden desk. Left page: blank area for a title with a large decorated initial letter in red and gold,
ruled lines for menu entries, small fleurons, an ink blot and quill marks. Right page: a hand-drawn
map of a village and surrounding forest. Aged parchment pages with soft edges, sepia ink, faded
red rubrication, gentle warm light from the top-left.
```

* **Negative extras:** `legible text, gibberish letters, modern UI buttons, glow, 3D book render`
* **Canvas:** 1920×1080, no transparency.
* **Post:** all text is live in Godot: title "The Smith's Chronicle" (IM Fell English SC, rubric
  drop capital "T"), entries Continue / New Game / Load Game / Settings / Credits / Quit (EB Garamond
  or Fell, each preceded by a fleuron ❧), version label bottom corner (EB Garamond 16 px, lnum).

### 4.8 `font_reference.png` — typography sheet

**Purpose:** reference for UI implementation, not for generation. Build it in Godot or a layout tool.

```text
Typography reference sheet on parchment #e9d8b0, ink #2b1d12. Sections: title "The Smith's
Chronicle" in IM Fell English SC with a rubricated drop capital; headings in IM Fell English;
UI text in EB Garamond 18-20 px; a dialogue sample with italic speaker name; buttons in normal,
hover (rubric underline), pressed (darker wash) and disabled (40 % ink) states; item names in the
six rarity colours on parchment and again on a dark tooltip; a stats table using EB Garamond with
lining tabular figures.
```

* **Canvas:** 1920×1080. Use exact hex values from the README rarity tables; do not let an image
  model render this (it cannot letter reliably).

---

## 5. Keeping consistency for additional assets

**Reference / seed strategy**
* Keep a *style anchor set*: blacksmith, tree, sword, and one building, approved and frozen. Feed
  1–2 of them as image references (IP-Adapter / style reference / `--sref`) on every generation.
* Record model, version, seed, sampler, guidance and reference weights per asset in a sidecar
  `.json` or spreadsheet row next to the file name.
* Train a small style LoRA once ~30 approved assets exist; lock it as the default.

**Palette lock** — after generation, map wash colours to the nearest README palette role
(posterise/indexed-colour pass or a LUT), then restore ink lines on top. Reject outputs with
saturation clearly above the palette.

**Line weight & hatch angle lock** — measure: outline 2.4 px (actors 3.6 px) at 512; hatch −35°/+35°.
Hatching at other angles must be redrawn or masked off and replaced with the shader hatch.

**Light direction** — top-left only. Flip-check: if the shadow is on the left, regenerate (never fix
by mirroring a character, which would also swap pauldron/hammer sides).

**Scale reference sheet** — maintain `ref_scale_sheet.png`: blacksmith, adventurer, door, barrel,
anvil, tree and a 64 px tile grid side by side at game scale; check every new asset against it.

**Post-processing checklist**
1. Straight top-down? (no visible side walls, no faces seen from front)
2. Transparent background, no parchment/grain baked in, no stray pixels; straight alpha.
3. Palette mapped; no pure black; rubric red only as accent.
4. Outline and hatch weights match at target size (check at 128 px, not only 512).
5. Light top-left, hatched ground shadow bottom-right.
6. No generated text or pseudo-letters.
7. Canvas size, margin and pivot per [`naming_guide.md`](naming_guide.md); file named correctly.

**Fill-in-the-blank template**

```text
[MASTER STYLE PROMPT]
Single [character / prop / building / icon] sprite, [straight top-down view from directly above,
facing south | inventory icon, view: ___]. Subject: [who/what], [age/build/size relative to the
blacksmith], wearing/made of [materials -> palette roles: ___], holding/featuring [items],
distinctive detail: [1-2 storytelling details: scars, repairs, wear]. Accent colour: [rubric red /
gold / forge glow / none]. Hatched ground shadow toward the bottom-right. Isolated on transparent
background, centred, [margin] px margin, canvas [512x512 | other].
Negative: [MASTER NEGATIVE] + [subject-specific exclusions]
```
