# Prompts — 08 Ink & Parchment, Gothic-Tempered · "The Smith's Chronicle"

Prompts for producing production-quality versions of the eight examples (and new assets) with an
image model, or for briefing an illustrator. The example PNGs are procedural SVG style studies (see
[README](README.md#rendering-note-read-first)); use them as palette, value and composition
references, not as quality targets.

**Rule for every prompt in this file:** it is an Ink & Parchment prompt first (≈ 85 %), with a short,
named list of Gothic Noir accents for *that* asset (≈ 15 %). Never prompt "dark fantasy" or "gothic"
on its own — image models read those words as "make everything black". The accents are always
described as techniques with limits.

No reference images were provided for this hybrid; it is derived from
[`../04_ink_parchment/prompts.md`](../04_ink_parchment/prompts.md) and
[`../01_gothic_noir/prompts.md`](../01_gothic_noir/prompts.md). If references are supplied later,
re-check the master prompt against them.

---

## 1. Master hybrid prompt

Prefix every asset prompt with this block (adapt syntax to the model: weights, `--no`, etc.).

```text
Ink-and-parchment fantasy illustration in the style of an engraved medieval manuscript and a
hand-drawn campaign map, tempered with a light touch of gothic atmosphere. PRIMARY STYLE: sepia
iron-gall ink linework (#24170e), confident hand-inked contours with slight natural wobble, thinner
interior detail lines; shading built from fine diagonal hatching at -35 degrees and cross-hatching at
+35 degrees on the shadow side; pale, low-saturation watercolour washes in earthy tones (aged
leather, muted wood, iron grey, faded ochre, sage green, faded red-brown); highlights left as
unpainted paper; light from the top-left, shadows to the bottom-right; naturalistic proportions.
SECONDARY ACCENTS, SUBTLE: slightly heavier ink outline than a classic manuscript; deeper, denser
cross-hatching in the core shadows; light soot, wear and age marks where use would put them; a thin
warm ember-orange (#e0782a) rim of light only on metal, gold, gems and fire. Overall still light,
airy and readable, parchment-toned, not dark. Straight top-down orthographic view looking directly
down (tops of heads, shoulders, roofs and tree canopies), no perspective, no 3/4 angle. Crisp,
clean, game-asset quality, consistent line weight.
```

### Master negative prompt

```text
3/4 view, isometric, perspective, side view, horizon, photorealistic, 3D render, CGI, glossy,
airbrush, smooth gradients, heavy saturation, neon, black fills, pure black shadows, large dark
areas, low-key lighting overall, horror, gore, skulls, grimdark, oppressive darkness, fog, thick
cartoon outlines, cel shading, chibi, big head, exaggerated top-heavy silhouette, anime, pixel art,
blurry, painterly oil, watercolour bleeding outside lines, text, letters, watermark, signature,
frame, border (unless requested), parchment background on sprites, glow on cloth or skin, bloom,
lens flare, bokeh, modern objects
```

---

## 2. Consistent artistic & technical requirements

| Item | Lock |
|---|---|
| Identity | Ink & Parchment first; Gothic accents only as listed per asset |
| Camera | Straight top-down orthographic (icons: icon-specific views below) |
| Light | Top-left; form shadow bottom-right; cast shadow toward bottom-right |
| Ink | `#24170e`, outline 3.0 px at 512 px master; +1.2 px silhouette outline on actors and interactables |
| Hatch | −35° single hatch, +35° cross-hatch, pitch ~5 px, line ~1.1 px at 512 px; core shadows denser than 04 |
| Fill | Pale washes from the README palette (light/base/shadow per material); lit planes as light as 04 |
| Accents | Rubric `#8e2a16`, muted gold `#b88e3a`, ember `#e0782a`/`#ffc070` — ember only from the README reserved list |
| Soot | Low-frequency, 3–8 % of the sprite area, never on faces or the silhouette edge |
| Ground shadow | Hatched ellipse, never a blurred dark blob |
| Proportions | Naturalistic (as 04); no Gothic exaggeration |
| Background | Sprites: transparent. Compositions: parchment `#e2cea2` (menu: dark workbench around the book) |
| Text | Never let the model letter text; add all labels/titles in post or in Godot |
| Darkness | Daytime assets must pass the README squint test (Gothic shift ≤ 0.25) |

---

## 3. Transparent background & framing rules

As 04, unchanged:

* Sprites and icons are **ink + wash on transparency**. Never bake parchment, paper grain, soot
  overlay, glow or vignette into a sprite. If the model cannot output alpha, generate on flat white
  `#ffffff`, key out the white with a soft threshold and keep semi-transparent ink edges (straight
  alpha).
* **Glow is never baked into the colour sprite.** If an item needs a glow, generate (or paint) a
  separate emissive mask; see [`naming_guide.md`](naming_guide.md).
* 512×512 master canvas, subject centred horizontally, ≥ 24 px empty margin (icons ≥ 32 px).
* Characters: feet/boots at ≈ y 410, hatched ground shadow beneath, facing south.
* Compositions are 1920×1080, 16:9, no transparency.

---

## 4. Individual prompts

Each prompt = **Master hybrid prompt + the text below**. Negative = master negative + extras listed.
Every asset prompt states its own Gothic allowance so the model is not left to guess.

### 4.1 `blacksmith.png` — protagonist

**Purpose:** player sprite master; defines scale, proportions and the soot/wear language.
**Gothic allowance:** slightly stronger outline, grit, soot on hands/apron/tools, worn leather;
*not* a dark character.

```text
Single game character sprite for a top-down 2D game, straight top-down view from directly above,
facing south (down the image), clearly readable at small size. An older, heavyset, experienced
retired adventurer who is now the village blacksmith. Bald scarred scalp seen from above with a
fringe of grey hair at the back, a leather eyepatch strap crossing the head diagonally. Big grey
braided beard with a gold beard-ring, projecting forward over a large belly. Leather apron with a
front pocket, belt with brass buckle and a pouch, apron straps crossing on his broad back. A single
old dented steel adventuring pauldron on his left shoulder. Leather bracers, bare hairy forearms.
A heavy sledgehammer hanging from his right hand (on the viewer's left), iron tongs at his left hip.
Boot toes peeking out below the belly. Manuscript ink-and-wash rendering as the main identity.
Allowed gothic accents only: a slightly heavier ink contour, soot smudges on the forearms, apron hem
and hammer head, a faint soot shadow on the scalp, scorch marks and worn creases on the leather,
a thin ember-orange rim of light on the pauldron edge and hammer head. Skin, beard and apron remain
pale washes, lit side bright. Hatched elliptical ground shadow toward the bottom-right. Isolated on
transparent background, centred, full figure within the frame.
```

* **Negative extras:** `face visible from front, eyes looking at viewer, two pauldrons, helmet, hair on top of head, thin body, soot on face or beard, dark skin wash, glowing eyes, menacing expression`
* **Canvas:** 512×512, transparent, feet centre at (256, ~410), ≥ 24 px margin.
* **Consistency:** this is the scale and grit reference for all actors. Pauldron on *his* left
  (viewer's right), hammer viewer's left. Soot ≈ 5 % of the sprite; check the squint test against
  `../04_ink_parchment/blacksmith.png`.

### 4.2 `adventurer.png` — visiting adventurer

**Purpose:** generic NPC/party member; shows a visitor who lives in a more dangerous world than the
village. **Gothic allowance:** slight edge — darker shadow side, worn, travel-stained kit, ember
glint on steel.

```text
Single game character sprite for a top-down 2D game, straight top-down view from directly above,
facing south, same scale and rendering as the blacksmith. A younger, slimmer adventurer. Round
wooden shield with a metal boss slung on the back over a muted red cloak; hair tied in a ponytail
with a cloth headband; steel pauldrons on both shoulders; leather jerkin and bracers; drawn sword
held point-forward in the right hand; dagger at the left hip; boots. Manuscript ink-and-wash
rendering as the main identity. Allowed gothic accents only: deeper cross-hatching on the shadow
side of the cloak and shield, a travel-worn frayed cloak hem, nicks on the shield rim, road dust on
the boots, a thin ember-orange glint on the sword edge and pauldron rims. Washes stay pale and
earthy. Hatched elliptical ground shadow toward the bottom-right. Isolated on transparent background,
centred.
```

* **Negative extras:** `bulky, heavyset, helmet covering head, bow, magic effects, blood, wounds, black cloak, hood shadowing face`
* **Canvas:** 512×512, transparent, feet centre at (256, ~410).
* **Consistency:** shoulder width ≈ 85 % of the blacksmith's; same line weight and hatch angle;
  cloak `#8a3e2c`, tunic dark blue-grey `#5e6c80`. Less soot than the smith (dust, not soot).

### 4.3 `sword.png` — inventory icon

**Purpose:** item icon master (128×128 in game). **Gothic allowance:** subtle darker metallic depth,
restrained dramatic accent on gold and gem; no glow baked in.

```text
Inventory icon for a 2D game, clearly readable at 64-128 px, of a single longsword lying diagonally
at 45 degrees, tip pointing to the top-right, pommel bottom-left. Steel blade with a central fuller
engraved with small runes, curled muted-gold crossguard with a central ember-red gem, leather-wrapped
grip with criss-cross binding, round gem pommel. Engraved manuscript ink linework as the main
identity; pale steel wash with a clear unpainted highlight streak along the upper edge. Allowed
gothic accents only: slightly deeper cross-hatched shadow along the lower-right edge of the blade,
a few fine wear scratches, a thin ember-orange rim of light on the crossguard, gem and pommel.
Isolated on transparent background, centred, filling about 80 % of the frame.
```

* **Negative extras:** `hand holding sword, scabbard, glow, aura, sparkles, flames, multiple swords, blood, black blade, dark steel overall`
* **Canvas:** 512×512, transparent, centred, ≥ 32 px margin.
* **Consistency:** all weapon icons use the 45° diagonal, tip top-right. The blade must keep a bright
  highlight — the study's sword runs too dark (README *Measured result*); aim lighter. Legendary
  variants add a separate `_emit` mask rather than a painted glow.

### 4.4 `armor.png` — inventory icon

**Purpose:** armour icon master. **Gothic allowance:** weathered, darkened creases, a little soot;
plates still clearly separated and readable.

```text
Inventory icon for a 2D game, clearly readable at 64-128 px, of a plate armour set seen from the
front, no wearer: breastplate with a central ridge and a small muted-gold anvil emblem with an
ember-red stud above it, gorget at the neck, three-lame pauldrons on both shoulders, faulds below
the waist, two tassets, leather side straps with buckles, visible rivets. Engraved manuscript ink
linework, -35 degree hatching on the right-hand side of each plate, pale steel wash as the main
identity. Allowed gothic accents only: darkened creases where plates overlap, two or three faint
soot smudges, small dents and scratch lines, a thin ember rim on the emblem. Each plate must stay
distinct and lit from the top-left. Isolated on transparent background, centred, symmetrical.
```

* **Negative extras:** `person wearing it, helmet, arms, legs, mannequin, stand, glow, rust everywhere, black armour, battle damage holes`
* **Canvas:** 512×512, transparent, centred, ≥ 32 px margin.
* **Consistency:** front view, symmetric, top-left light. Wear asymmetric but light (≤ 8 % area).

### 4.5 `tree.png` — environment

**Purpose:** canopy sprite master for forests and the village. **Gothic allowance:** slightly moodier
line and grounding only; no dark foliage.

```text
Single deciduous tree for a top-down 2D game, seen straight from above as on a hand-drawn map: a
rounded canopy of overlapping foliage clusters, each cluster outlined with scalloped leaf marks,
sage-green washes in two tones, hatched shadow on the lower-right side of each cluster, the base of
the trunk just peeking out at the bottom. Manuscript map rendering as the main identity. Allowed
gothic accents only: a slightly heavier contour line and denser cross-hatching where clusters
overlap, and a firm hatched cast shadow toward the bottom-right that grounds the tree. Canopy tops
stay pale and sunlit. Isolated on transparent background, centred.
```

* **Negative extras:** `side view of trunk, roots, side-view tree, pine, flowers, fruit, dead tree, gnarled branches, dark foliage, mist`
* **Canvas:** 512×512, transparent; anchor = trunk base.
* **Consistency:** foliage `#849064`, foliage2 `#989058`; 3–4 variants per species. No soot on
  nature assets except near the smithy (handled by the overlay in-engine).

### 4.6 `town_view.png` — village as illustrated map

**Purpose:** key art for the world view and the lighting reference for dusk.
**Gothic allowance:** stronger lighting contrast and warm forge and inn glows; still a readable
manuscript map.

```text
Straight top-down view of a small medieval fantasy village drawn as a hand-illustrated manuscript
map on aged parchment, for a top-down 2D game; every building, road and figure clearly readable.
Central crossroads square with a stone well and a market stall. South-west of the square the
blacksmith's workshop: stone walls, grey slate roof, chimney, open forge yard with anvil, forge,
quench trough and weapon rack. North-east the inn, the largest building, L-shaped with a tiled roof,
a stable and beer-garden tables. Several cottages, a small chapel, wooden fences, crates and barrels.
A stream with a wooden bridge on the east side. Forest edge to the north and west drawn as massed
scalloped canopies. Tiny figures in the streets. Ornamental double-rule border with corner fleurons,
a compass rose in a corner, empty cartouches for labels. Ink linework with hatched shadows to the
bottom-right, pale watercolour washes, deep red-brown accents. Allowed gothic accents only: late
afternoon light, the page gently dimming toward the bottom-right corner; a warm ember-orange glow
pooling in the open forge yard (the brightest point of the image), softer warm glows at the inn door
and beer-garden lanterns; a thin smudge of soot drifting from the smithy chimney; a few embers;
slightly firmer edge vignette. The village remains clearly daytime-readable.
```

* **Negative extras:** `perspective, isometric buildings, side walls visible, legible text, modern map symbols, grid, night, moon, black sky, fog, more than three bright lights`
* **Canvas:** 1920×1080, parchment background, no transparency.
* **Post:** labels in IM Fell English italic, rubric `#8e2a16` for key places — "The Tipsy Wyvern",
  "The Smithy", "Chapel of the Dawn", "Market Square"; cartouche "Brindlewick · The Village".
* **Consistency:** buildings at 64 px/tile (inn ≈ 6×4 tiles, smithy ≈ 4×3 incl. yard). In the game
  this grade is produced by `CanvasModulate` + lights, not painted; the image is a target, not an asset.

### 4.7 `menu_screen.png` — main menu

**Purpose:** UI key art; the chronicle becomes the smith's ledger. **Gothic allowance:** stronger
contrast around the book, ember and deep brown, tactile crafted elements; the pages stay clear.

```text
An open leather-bound ledger lying flat on a dark wooden workbench, seen from directly above,
filling most of the frame. Warm forge light glows in from the bottom-left corner and a candle glows
at the top-right; a few embers drift over the bench. Left page: a large illuminated initial letter in
deep red-brown inside a double-ruled box with hatched ground, ruled ledger columns for menu entries
with dotted leaders, small fleurons, a red wax seal near the bottom corner. Right page: a framed
hand-drawn map of a village and surrounding forest, and below it small engraved figure plates of a
blacksmith, a sword and a breastplate. Aged parchment pages, sepia ink, faded red-brown
rubrication as the main identity. Allowed gothic accents only: heavier burnt-edge shadows at the
page gutters and corners, darker surroundings, warm ember glow on the bench, soft overall vignette.
The pages themselves remain light and readable.
```

* **Negative extras:** `legible text, gibberish letters, modern UI buttons, 3D book render, skulls, candles on the pages, dark pages, blood, chains`
* **Canvas:** 1920×1080, no transparency.
* **Post (live in Godot):** header line (IM Fell English italic), title "The Smith's Chronicle"
  (IM Fell English SC, Grenze Gotisch initial "T" in `#8e2a16`), ledger rows with roman numerals and
  "fol." references: Continue (dimmed when unavailable) / New Game / Load Game / Settings / Credits /
  Quit; hover = rubric italic text + faint ember underlay; version label EB Garamond italic.
  Buttons must feel crafted (ruled rows, seal, leaders) but each entry stays ≥ 40 px and high contrast.

### 4.8 `font_reference.png` — typography sheet

**Purpose:** UI implementation reference, not for image generation. Build in Godot or a layout tool.
**Gothic allowance:** a touch more flair — blackletter initial, heavier borders, dark leather
dialogue, ember Legendary — without losing readability.

```text
Typography reference sheet on parchment #e2cea2 panels with heavy ink #24170e borders and a faint
forge glow in one corner. Sections: title "The Smith's Chronicle" in IM Fell English SC with a
Grenze Gotisch initial in #8e2a16; headings in IM Fell English (secondary heading in #8e2a16);
UI text in EB Garamond 18-20 px; a dialogue sample in a dark leather box with the speaker name in
ember #ff9a48 and choices in #f0d060; buttons in normal, hover (rubric border, italic, faint ember
glow), pressed (darker wash) and disabled (40 % ink, dashed) states; item names in the six rarity
colours on parchment and again on a dark tooltip, Legendary with a faint ember glow; a stats table
in EB Garamond with lining tabular figures.
```

* **Canvas:** 1920×1080. Use the exact hex values from the README rarity tables; do not let an image
  model render this.

---

## 5. Variant prompts: dusk, night and interiors

In the game these are **lighting states, not separate art** (`CanvasModulate` + `PointLight2D` +
overlays). Use variant prompts only for key art, concept paintings and to define light targets.
Here the Gothic share may rise to **≈ 25–30 %**, never higher. Append to the asset prompt and drop the
"remains clearly daytime-readable" clause:

```text
VARIANT [dusk | night | forge interior | inn interior]: the same ink-and-parchment drawing, shaded
in as an illuminator would — denser -35/+35 degree hatching across the page in place of darkness,
a cool muted blue-grey cast at night; [the forge | the hearth and two candles | the inn door and
lanterns] as the strongest warm ember-orange light, erasing the hatching inside its pool; at most
three light sources; soot on walls and floor near the fire; embers rising. Paths, doors and figures
remain legible; parchment still visible in the lit areas; no pure black.
```

Extra negatives: `pitch black, horror, fog bank, moonlit blue scene, neon, glowing eyes`.

---

## 6. Keeping consistency for additional assets

**Reference / seed strategy** — as 04: freeze a *style anchor set* (blacksmith, tree, sword, one
building) and feed 1–2 as image/style references on every generation. Add a **pair check**: keep the
matching 04 asset next to each new 08 asset in the review sheet. Record model, seed, sampler, guidance
and reference weights in a sidecar per asset. Train a style LoRA after ~30 approved assets; if the
LoRA is trained on 08 outputs only, it will drift darker over time — mix in ~30 % 04 assets.

**Palette lock** — map washes to the README palette roles (LUT/indexed pass), then restore ink lines.
Reject outputs where ember appears outside the reserved list or saturation exceeds the palette.

**Value lock** — measure the Gothic shift index (README) on each batch; ≤ 0.25 by day. If the model
darkens, *reduce* the accent sentence rather than adding "light" adjectives.

**Line weight & hatch lock** — outline 3.0 px (+1.2 px actor silhouette) at 512 px; −35°/+35° hatch.

**Light direction** — top-left only; never fix by mirroring an asymmetric character.

**Post-processing checklist**
1. Reads as Ink & Parchment first? Squint test vs 04 and 01 passed?
2. Straight top-down; transparent background; no parchment, soot overlay or glow baked in.
3. Palette mapped; ember only on reserved elements; no pure black.
4. Soot ≤ 8 %, not on faces or silhouette edges.
5. Outline and hatch weights correct at target size (check at 128 px).
6. Light top-left, hatched ground shadow bottom-right.
7. No generated text or pseudo-letters.
8. Canvas, margin, pivot and companion masks (`_wear`, `_emit`) per [`naming_guide.md`](naming_guide.md).

**Fill-in-the-blank template**

```text
[MASTER HYBRID PROMPT]
Single [character / prop / building / icon] for a top-down 2D game, [straight top-down view from
directly above, facing south | inventory icon, view: ___], clearly readable at [128 | 64] px.
Subject: [who/what], [age/build/size relative to the blacksmith], wearing/made of [materials ->
palette roles: ___], holding/featuring [items], distinctive detail: [1-2 storytelling details:
scars, repairs, wear]. Manuscript ink-and-wash rendering as the main identity.
Allowed gothic accents only: [pick 1-3: heavier contour | deeper core cross-hatching |
soot on ___ | worn/darkened creases on ___ | ember rim on (metal/gold/gem/fire) ___ ].
Lit side stays pale. Accent colour: [rubric red-brown / muted gold / ember (reserved list only) /
none]. Hatched ground shadow toward the bottom-right. Isolated on transparent background, centred,
[margin] px margin, canvas [512x512 | other].
Negative: [MASTER NEGATIVE] + [subject-specific exclusions]
```
