# Prompts — Ink & Parchment / Gothic Noir 80:20 · "Ember & Ash"

Prompts for producing production-quality versions of the eight examples (and new assets) with an
image model, or for briefing an illustrator. The example PNGs are procedural SVG style studies (see
[README](README.md#rendering-note-read-first)); use them as palette, value, wear and composition
references, not as quality targets.

**Rule for every prompt in this file:** it is an Ink & Parchment prompt first (≈ 80 %), with a short,
named list of Gothic Noir accents for *that* asset (≈ 20 %). The step from 85:15 is made by naming
*more or stronger techniques* (heavier line, deeper core hatching, scratches, lit runes, more light
pools) — never by adding "darker", "grim", "dark fantasy" or "gothic" on their own. Image models read
those words as "make everything black".

These prompts are derived from [`../08_ink_parchment_gothic/prompts.md`](../08_ink_parchment_gothic/prompts.md)
(85:15). Section 7 explains how to produce matched 85:15 / 80:20 pairs. No reference images were
provided; if references are supplied later, re-check the master prompt against them.

---

## 1. Master hybrid prompt (80:20)

Prefix every asset prompt with this block (adapt syntax to the model: weights, `--no`, etc.).

```text
Ink-and-parchment fantasy illustration in the style of an engraved medieval manuscript and a
hand-drawn campaign map, about 80 percent ink and parchment and 20 percent gothic atmosphere.
PRIMARY STYLE (dominant): sepia iron-gall ink linework (#20140c), confident hand-inked contours with
slight natural wobble, thinner interior detail lines; shading built from fine diagonal hatching at
-35 degrees and cross-hatching at +35 degrees on the shadow side; pale, low-saturation watercolour
washes in earthy tones (aged leather, muted wood, iron grey, faded ochre, sage green); highlights
left as unpainted paper; light from the top-left, shadows to the bottom-right; naturalistic
proportions. SECONDARY ACCENTS (clearly visible but restrained): a firm, heavier ink outline around
each figure or object; deep, dense cross-hatching in the core shadows; worn surfaces with fine
scratches, small nicks and cracked leather where use would put them; light soot in creases and on
tools; charcoal, dark-brown and muted burgundy accents; a thin warm ember-orange (#e6702a) rim of
light on metal, gold, gems and fire only; on magical or legendary items, small runes lit from within
by ember light. Lit sides stay as pale and warm as a classic manuscript; the image overall is
parchment-toned, warm and readable, not dark. Straight top-down orthographic view looking directly
down (tops of heads, shoulders, roofs and tree canopies), no perspective, no 3/4 angle. Crisp,
clean, game-asset quality, consistent line weight.
```

### Master negative prompt

```text
3/4 view, isometric, perspective, side view, horizon, photorealistic, 3D render, CGI, glossy,
airbrush, smooth gradients, heavy saturation, neon, black fills, pure black shadows, large dark
areas, low-key lighting overall, dark background, horror, gore, skulls, grimdark, oppressive
darkness, fog, rust everywhere, heavy grunge texture, thick cartoon outlines, cel shading, chibi,
big head, exaggerated top-heavy silhouette, anime, pixel art, blurry, painterly oil, watercolour
bleeding outside lines, text, letters, watermark, signature, frame, border (unless requested),
parchment background on sprites, glow on cloth or skin, glowing eyes, bloom, lens flare, bokeh,
modern objects
```

---

## 2. Consistent artistic & technical requirements

| Item | Lock |
|---|---|
| Identity | Ink & Parchment first; Gothic accents only as listed per asset |
| Camera | Straight top-down orthographic (icons: icon-specific views below) |
| Light | Top-left; form shadow bottom-right; cast shadow toward bottom-right |
| Ink | `#20140c`, outline 3.2 px at 512 px master (thin icons 2.8 px); +1.5 px silhouette on actors and interactables (thin icons 1.2 px) |
| Hatch | −35° single, +35° cross-hatch, pitch ~5 px, line ~1.1 px at 512 px; core shadows denser than 08 |
| Fill | Pale washes from the README palette; lit planes as light as 04 |
| Accents | Burgundy `#7e2418`, gilt `#b8923e` (ornament), muted gold `#c69c44` (metal), ember `#e6702a`/`#ffc070` — ember and runes only from the README reserved list |
| Wear | 2–5 fine scratch/crack lines per surface, ink at 50–70 %; never on faces or the silhouette edge |
| Soot | Low-frequency, 5–10 % of the sprite area |
| Ground shadow | Hatched ellipse, never a blurred blob |
| Proportions | Naturalistic (as 04/08); no Gothic exaggeration |
| Background | Sprites: transparent. Compositions: parchment `#dcc79a` (menu: dark workbench around the book) |
| Text | Never let the model letter text; add titles/labels in post or in Godot |
| Darkness | Gothic shift ≤ 0.25 day / ≤ 0.30 items / ≤ 0.35 night-interiors (README) |

---

## 3. Transparent background & framing rules

As 08, unchanged:

* Sprites and icons are **ink + wash on transparency**. Never bake parchment, paper grain, soot
  overlay, glow or vignette into a sprite. If the model cannot output alpha, generate on flat white
  `#ffffff`, key out the white with a soft threshold and keep semi-transparent ink edges (straight
  alpha).
* **Glow is never baked into the colour sprite** — not even rune glow. Runes are drawn as ink marks
  on the metal; the ember light is a separate `_emit` mask ([`naming_guide.md`](naming_guide.md)).
  For the master you may generate a "lit" version for reference, then extract the mask from it.
* 512×512 master canvas, subject centred horizontally, ≥ 24 px margin (icons ≥ 32 px).
* Characters: feet at ≈ y 410, hatched ground shadow beneath, facing south.
* **Same canvas, framing and pivot as the 85:15 asset** — never re-frame for 80:20.
* Compositions are 1920×1080, 16:9, no transparency.

---

## 4. Individual prompts

Each prompt = **master hybrid prompt + the text below**. Negative = master negative + extras.
Every asset prompt states its own 80:20 allowance.

### 4.1 `blacksmith.png` — protagonist

**Purpose:** player sprite master; defines scale, proportions, wear and soot language.
**80:20 allowance:** firmer outline, more soot, cracked apron, scratched pauldron and hammer face,
stronger ember rim on metal. Lit side and face stay warm.

```text
Single game character sprite for a top-down 2D game, straight top-down view from directly above,
facing south (down the image), clearly readable at small size. An older, heavyset, experienced
retired adventurer who is now the village blacksmith. Bald scarred scalp seen from above with a
fringe of grey hair at the back, a leather eyepatch strap crossing the head diagonally. Big grey
braided beard with a gold beard-ring, projecting forward over a large belly. Leather apron with a
front pocket, belt with brass buckle and a pouch, dark-brown apron straps crossing on his broad
back. A single old dented steel adventuring pauldron on his left shoulder. Leather bracers, bare
hairy forearms. A heavy sledgehammer hanging from his right hand (on the viewer's left), iron tongs
at his left hip. Dark charcoal-brown boot toes peeking out below the belly. Manuscript ink-and-wash
rendering as the main identity. Allowed gothic accents: a firm heavier ink contour around the whole
figure; soot smudges on the forearms, apron hem and hammer head; a faint soot shadow on the scalp;
fine cracks and scorch marks on the apron leather; a few fine scratches on the pauldron and on the
hammer's striking face; deep cross-hatching in the core shadows; a thin ember-orange rim of light on
the pauldron edge and hammer head. Skin, beard and apron remain pale washes, lit side bright and
warm. Hatched elliptical ground shadow toward the bottom-right. Isolated on transparent background,
centred, full figure within the frame.
```

* **Negative extras:** `face visible from front, eyes looking at viewer, two pauldrons, helmet, hair on top of head, thin body, soot on face or beard, scratches on skin, dark skin wash, glowing eyes, menacing expression`
* **Canvas:** 512×512, transparent, feet centre (256, ~410), ≥ 24 px margin.
* **Consistency:** scale, wear and soot reference for all actors. Pauldron on *his* left (viewer's
  right), hammer viewer's left. Soot ≈ 6–8 %. Target Gothic shift ≈ 0.23 (study); pair-check against
  `../08_ink_parchment_gothic/blacksmith.png`.

### 4.2 `adventurer.png` — visiting adventurer

**Purpose:** generic NPC/party member from a more dangerous world. **80:20 allowance:** muted
burgundy cloak, charcoal straps and boots, frayed hem, shield nicks, ember glint on steel. Keep the
cloak's lit side warm — this asset is at the ceiling in the study (0.25).

```text
Single game character sprite for a top-down 2D game, straight top-down view from directly above,
facing south, same scale and rendering as the blacksmith. A younger, slimmer adventurer. Round
wooden shield with a metal boss slung on the back over a muted burgundy cloak; hair tied in a
ponytail with a cloth headband; steel pauldrons on both shoulders; leather jerkin and bracers with
dark-brown straps; drawn sword held point-forward in the right hand; dagger at the left hip;
charcoal-brown boots. Manuscript ink-and-wash rendering as the main identity. Allowed gothic
accents: a firm heavier ink contour; deeper cross-hatching on the shadow side of the cloak and
shield; a travel-worn frayed cloak hem; small nicks on the shield rim and sword edge; road dust on
the boots; a thin ember-orange glint on the sword edge and pauldron rims. The cloak's lit side stays
a pale dusty rose-burgundy; washes stay earthy. Hatched elliptical ground shadow toward the
bottom-right. Isolated on transparent background, centred.
```

* **Negative extras:** `bulky, heavyset, helmet covering head, bow, magic effects, blood, wounds, black cloak, wine-red saturated cloak, hood shadowing face`
* **Canvas:** 512×512, transparent, feet centre (256, ~410).
* **Consistency:** shoulder width ≈ 85 % of the blacksmith's; cloak `#b46e66` / `#8e3e3c` /
  `#4a1a1a`, tunic `#6a7a92`. Dust, not soot. For daytime exteriors the 85:15 cloak can be
  restored by palette remap (README verdict).

### 4.3 `sword.png` — inventory icon

**Purpose:** item icon master (128×128 in game). **80:20 allowance:** runes along the fuller lit with
ember light, edge nicks, scratches, stronger ember rim on gold and gem. Thin-icon rule: **2.8 px
outline, 1.2 px silhouette** (study at 3.2 px measured 0.32 — too dark).

```text
Inventory icon for a 2D game, clearly readable at 64-128 px, of a single longsword lying diagonally
at 45 degrees, tip pointing to the top-right, pommel bottom-left. Steel blade with a central fuller
engraved with a short row of small angular runes, curled muted-gold crossguard with a central
deep ember-red gem, leather-wrapped grip with criss-cross binding, round gem pommel. Engraved
manuscript ink linework, slightly finer outline than the characters, as the main identity; pale
steel wash with a clear unpainted highlight streak along the upper edge of the blade. Allowed gothic
accents: the runes in the fuller glowing faintly from within with ember-orange light; two or three
small nicks along the lower cutting edge; a few fine wear scratches on the blade; deeper
cross-hatched shadow along the lower-right edge; a thin ember-orange rim of light on the crossguard,
gem and pommel. Isolated on transparent background, centred, filling about 80 % of the frame.
```

* **Negative extras:** `hand holding sword, scabbard, aura, sparkles, flames, glow outside the blade, multiple swords, blood, black blade, dark steel overall, runes over the whole blade`
* **Canvas:** 512×512, transparent, centred, ≥ 32 px margin.
* **Consistency:** 45° diagonal, tip top-right for all weapons. The highlight streak must survive.
  Rune glow goes into `eqp_sword_<name>_emit.png`; the colour sprite keeps the runes as ink marks
  only. Ordinary (non-magical) swords get nicks and scratches but **no** runes. Target ≤ 0.30.

### 4.4 `armor.png` — inventory icon

**Purpose:** armour icon master. **80:20 allowance:** scratches, soot in creases, a small ember-lit
rune under the emblem, ember rim on the emblem; plates still clearly separated.

```text
Inventory icon for a 2D game, clearly readable at 64-128 px, of a plate armour set seen from the
front, no wearer: breastplate with a central ridge and a small muted-gold anvil emblem with a deep
ember-red stud above it and a small single rune engraved just below it, gorget at the neck,
three-lame pauldrons on both shoulders, faulds below the waist, two tassets, dark-brown leather side
straps with buckles, visible rivets. Engraved manuscript ink linework, -35 degree hatching on the
right-hand side of each plate, pale steel wash as the main identity. Allowed gothic accents: a firm
heavier contour; darkened creases where plates overlap; two or three soft soot smudges; several fine
scratch lines and small dents; the rune below the emblem glowing faintly ember-orange; a thin ember
rim on the emblem. Each plate stays distinct and lit from the top-left. Isolated on transparent
background, centred, symmetrical.
```

* **Negative extras:** `person wearing it, helmet, arms, legs, mannequin, stand, aura, rust everywhere, black armour, battle damage holes, blood`
* **Canvas:** 512×512, transparent, centred, ≥ 32 px margin.
* **Consistency:** front view, symmetric silhouette, wear asymmetric and light (≤ 10 %). Rune glow
  in `_emit`. Target ≈ 0.21 (study).

### 4.5 `tree.png` — environment

**Purpose:** canopy sprite master. **80:20 allowance:** heavier contour and denser overlap
cross-hatching only. Nature barely changes at 80:20 (study 0.14) — keep it that way.

```text
Single deciduous tree for a top-down 2D game, seen straight from above as on a hand-drawn map: a
rounded canopy of overlapping foliage clusters, each cluster outlined with scalloped leaf marks,
sage-green washes in two tones, hatched shadow on the lower-right side of each cluster, the base of
the trunk just peeking out at the bottom. Manuscript map rendering as the main identity. Allowed
gothic accents: a firm heavier contour line and deep cross-hatching where clusters overlap, and a
firm hatched cast shadow toward the bottom-right. Canopy tops stay pale and sunlit.
Isolated on transparent background, centred.
```

* **Negative extras:** `side view of trunk, roots, pine, flowers, fruit, dead tree, gnarled branches, dark foliage, mist, soot, scratches`
* **Canvas:** 512×512, transparent; anchor = trunk base.
* **Consistency:** foliage `#909c6c`, foliage2 `#a49c62`; 3–4 variants per species. No soot or wear
  on nature; soot near the smithy comes from the in-engine overlay.

### 4.6 `town_view.png` — village as illustrated map

**Purpose:** world-view key art and the lighting reference for dusk ("as the light fails").
**80:20 allowance:** soot streaks below chimneys, a faint soot darkening along the main streets,
lantern and inn-window pools, a magical rune ring at the old well, dusk dimming toward the
bottom-right. Still a readable manuscript map.

```text
Straight top-down view of a small medieval fantasy village drawn as a hand-illustrated manuscript
map on aged parchment, for a top-down 2D game; every building, road and figure clearly readable.
Central crossroads square with an old stone well and a market stall. South-west of the square the
blacksmith's workshop: stone walls, grey slate roof, chimney, open forge yard with anvil, forge,
quench trough and weapon rack. North-east the inn, the largest building, L-shaped with a tiled roof,
a stable and beer-garden tables. Several cottages, a small chapel, wooden fences, crates and barrels.
A stream with a wooden bridge on the east side. Forest edge to the north and west drawn as massed
scalloped canopies. Tiny figures in the streets. Ornamental double-rule border with corner fleurons,
a compass rose in a corner, empty cartouches for labels. Ink linework with hatched shadows to the
bottom-right, pale watercolour washes, muted burgundy accents. Allowed gothic accents: late
afternoon light as the day fails, the page dimming gently toward the bottom-right corner; a warm
ember-orange glow pooling in the open forge yard (the brightest point of the image); softer warm
glows at the inn door and windows, beer-garden lanterns and a few street lanterns; a smudge of soot
drifting from the smithy chimney and faint soot streaks on the roofs below every chimney; the main
streets very faintly sooted by traffic; a faint gold dashed ring of runes around the old well with a
soft magical glow; a few embers; a firmer edge vignette. The village remains clearly readable and
warm, parchment visible everywhere.
```

* **Negative extras:** `perspective, isometric buildings, side walls visible, legible text, modern map symbols, grid, night, moon, black sky, fog, smoke clouds covering buildings, more than three bright lights, dirty brown wash over the whole map`
* **Canvas:** 1920×1080, parchment, no transparency.
* **Post:** labels in IM Fell English italic, burgundy `#7e2418` for key places — "The Tipsy Wyvern",
  "The Smithy", "Chapel of the Dawn", "Market Square"; cartouche "Brindlewick · The Village".
* **Consistency:** 64 px/tile (inn ≈ 6×4 tiles, smithy ≈ 4×3 incl. yard). In game this is
  `CanvasModulate` + lights + placed soot masks, not painted. For a **daytime** reference, drop the
  street-soot clause and "as the day fails" (85:15 values, README verdict).

### 4.7 `menu_screen.png` — main menu "Ember & Ash"

**Purpose:** UI key art. **80:20 allowance:** dark ornamental corner pieces with restrained gilt,
burgundy blackletter initial, stronger forge glow and embers, firmer vignette; the pages stay clear.

```text
An open leather-bound ledger lying flat on a dark wooden workbench, seen from directly above,
filling most of the frame. Warm forge light glows in from the bottom-left corner and a candle glows
at the top-right; embers drift over the bench. Each page has small dark-iron corner brackets with
restrained gilt leaf ornaments. Left page: a large empty square for an illuminated initial, framed
with a thin gilt rule and filled with fine hatched ground; ruled ledger columns with dotted leaders
for menu entries, a thin gilt rule under the column heads, a small gilt fleuron, a deep red wax seal
near the bottom corner. Right page: a framed hand-drawn village map with a thin gilt outer rule, and
below it small engraved figure plates of a blacksmith, a runed sword and a breastplate. Aged
parchment pages, sepia ink, muted burgundy rubrication as the main identity. Allowed gothic accents:
heavier burnt-edge shadows at the gutters and corners, darker surroundings, warm ember glow on the
bench, a soft firm vignette, restrained gold leaf on ornaments only. The pages themselves remain
light, warm and readable.
```

* **Negative extras:** `legible text, gibberish letters, modern UI buttons, 3D book render, skulls, chains, candles on the pages, dark pages, blood, heavy gold, gold leaf everywhere, metallic shine`
* **Canvas:** 1920×1080, no transparency.
* **Post (live in Godot):** header "Ledger of Ember & Ash · the Forge at Brindlewick" (IM Fell English
  italic); title "Ember & Ash" — Grenze 800 initial "E" in burgundy `#7e2418` with faint ember
  glow in the gilt-framed box (the blackletter "E" misreads as "IE"), "mber / & Ash" in IM Fell English SC `#20140c`. Rows with roman numerals and "fol."
  references: Continue (dimmed when unavailable) / New Game / Load Game / Settings / Credits / Quit;
  hover = burgundy italic + faint ember underlay. Plate caption "Plate I. — Brindlewick as the light
  fails; the forge, the inn and the old well still burning." Each entry ≥ 40 px, high contrast.

### 4.8 `font_reference.png` — typography sheet

**Purpose:** UI implementation reference; build in Godot or a layout tool, never with an image model.
**80:20 allowance:** burgundy blackletter initial with ember glow, burgundy secondary headings, thin
gilt inner frames and label rules, warmer dialogue glow, stronger Legendary glow.

```text
Typography reference sheet on parchment #dcc79a panels with heavy ink #20140c borders, a thin gilt
#b8923e inner frame inset 8 px, gilt label underlines and a faint forge glow in one corner. Sections:
title "Ember & Ash" in IM Fell English SC with a Grenze initial "E" in #7e2418 and a soft
ember glow; headings in IM Fell English (secondary heading in #7e2418); UI text in EB Garamond
18-20 px; a dialogue sample in a dark leather box with a warm inner ember glow, speaker name in
#ff9a48 and choices in #f0d060; buttons in normal, hover (burgundy border, italic, ember glow),
pressed and disabled states; item names in the six rarity colours on parchment and on a dark
tooltip, Legendary with an ember glow; a stats table in EB Garamond with lining tabular figures.
```

* **Canvas:** 1920×1080. Use the exact hex values from the README rarity tables; gilt never as text.

---

## 5. Variant prompts: dusk, night and interiors

In the game these are **lighting states, not separate art**. Use variant prompts for key art and
light targets only. At 80:20 the Gothic share here may rise to **≈ 30–35 %**, never higher. Append to
the asset prompt and drop the "remains clearly readable and warm" clause:

```text
VARIANT [dusk | night | forge interior | inn interior]: the same ink-and-parchment drawing, shaded in
as an illuminator would — denser -35/+35 degree hatching across the page in place of darkness, a cool
muted blue-grey cast at night; [the forge | the hearth and two candles | the inn door, windows and
lanterns] as the strongest warm ember-orange light, erasing the hatching inside its pool; at most
three strong lights plus a few faint candle or lantern pools; soot on walls, floor and roofs near the
fire; embers rising; runes on magical objects glowing softly. Paths, doors and figures remain
legible; parchment still visible in the lit areas; no pure black.
```

Extra negatives: `pitch black, horror, fog bank, moonlit blue scene, neon, glowing eyes`.

---

## 6. Keeping consistency for additional assets

**Reference / seed strategy** — freeze a style anchor set (blacksmith, tree, runed sword, one
building) and feed 1–2 as image/style references on every generation. Review every new asset next to
its 08 counterpart **and** its 04 counterpart. Record model, seed, sampler, guidance and reference
weights in a sidecar. When training a style LoRA, mix ~40 % 08 assets into the 80:20 set to stop
cumulative darkening.

**Palette lock** — map washes to the README roles (LUT/indexed pass), then restore ink lines. Reject
ember outside the reserved list, runes on non-magical items, gilt as fill or text.

**Value lock** — measure the Gothic shift per batch: ≤ 0.25 day, ≤ 0.30 items, ≤ 0.35 night and
interiors. If a batch darkens, *remove an accent* from the allowance rather than adding "light".

**Line & hatch lock** — 3.2 px outline (+1.5 px silhouette), thin icons 2.8 / 1.2 px; −35°/+35°.

**Wear lock** — 2–5 fine marks per surface; if the model produces texture-grunge, reduce to "a few
fine scratches" and add `grunge, distressed texture` to the negative.

**Light direction** — top-left only; never fix by mirroring an asymmetric character.

**Post-processing checklist**
1. Reads as Ink & Parchment first? Squint test vs 08, 04 and 01 passed?
2. Straight top-down; transparent; no parchment, soot overlay or glow baked in.
3. Palette mapped; ember, runes and gilt only where allowed; no pure black.
4. Soot 5–10 %; wear 2–5 marks per surface; not on faces or silhouette edges.
5. Outline and hatch weights correct at 128 px (thin icons 2.8 px).
6. Light top-left; hatched ground shadow bottom-right.
7. No generated text or pseudo-letters (runes are marks, not legible script).
8. Same canvas, pivot and framing as the 85:15 asset; companion `_g20`, `_wear`, `_emit` per
   [`naming_guide.md`](naming_guide.md).

**Fill-in-the-blank template**

```text
[MASTER HYBRID PROMPT 80:20]
Single [character / prop / building / icon] for a top-down 2D game, [straight top-down view from
directly above, facing south | inventory icon, view: ___], clearly readable at [128 | 64] px.
Subject: [who/what], [age/build/size relative to the blacksmith], wearing/made of [materials ->
palette roles: ___], holding/featuring [items], distinctive detail: [1-2 storytelling details].
Manuscript ink-and-wash rendering as the main identity.
Allowed gothic accents: [pick 2-4: firm heavier contour | deep core cross-hatching |
fine scratches/nicks on ___ | cracked leather on ___ | soot on ___ | charcoal/dark-brown/muted
burgundy accent on ___ | ember rim on (metal/gold/gem/fire) ___ | ember-lit runes on ___ (magical or
legendary only) ].
Lit side stays pale and warm. Accent colour: [muted burgundy / gilt ornament / ember (reserved list
only) / none]. Hatched ground shadow toward the bottom-right. Isolated on transparent background,
centred, [margin] px margin, canvas [512x512 | other].
Negative: [MASTER NEGATIVE] + [subject-specific exclusions]
```

---

## 7. Producing matched 85:15 vs 80:20 pairs

The scene-dependent dial (README verdict) needs both registers for some assets. Make them a *pair*,
not two separate generations:

1. **Generate or paint the 85:15 asset first** from [`../08_ink_parchment_gothic/prompts.md`](../08_ink_parchment_gothic/prompts.md),
   same seed, canvas and framing. This is the shared base colour sprite.
2. **Derive the 80:20 layer from it**, never re-roll: image-to-image / inpaint at low denoise
   (≈ 0.25–0.35) with the 80:20 prompt, or have the artist paint on a separate layer: extra line
   weight (+0.2 px outline, +0.3 px silhouette), the deeper shadow step, scratches/cracks/nicks.
   Export that difference as `_g20` (see [`naming_guide.md`](naming_guide.md)).
3. **Paint runes and their light as `_emit`**, and soot extent as `_wear`; both serve both registers
   (only their strength changes).
4. **Palette differences** (burgundy cloak, darker strap/boot base) are applied by palette remap in
   the shader, not by a second colour sprite.
5. **Verify the pair:** the two composites must align pixel-for-pixel (silhouette, pivot, framing);
   measure the Gothic shift for both — expect ≈ +0.03 to +0.06 between them (sword +0.08 before the
   thin-icon fix). Put both into a comparison sheet like
   [`comparison_85_15_vs_80_20.png`](comparison_85_15_vs_80_20.png).
6. For compositions (town, menu), keep the 85:15 composition and add only the 80:20 overlay passes
   (soot streaks, extra pools, rune ring, gilt ornaments); never recompose.
