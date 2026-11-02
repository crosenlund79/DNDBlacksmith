# Prompts · 01 Gothic Noir Top-Down — "Embers of the Forgotten"

Prompts for producing **production-quality** versions of the eight example
images (and new assets) with an image-generation model, or for briefing an
illustrator. The PNGs in this folder are procedural SVG style studies (see the
rendering note in `README.md`); use them as composition/palette references, not
as final art.

> No reference images were found in the repository (the brief mentions four).
> If they are supplied later, re-check palette, proportions and wording here
> against them, and add them as style references to your generation setup.

Style references are to **techniques only** (heavy ink, hatching, desaturation,
grain — the "Darkest Dungeon-like" illustration school). Never ask a model to
reproduce that game's characters, assets or logo; avoid naming it in prompts
for commercial assets — the technique words below are sufficient.

---

## 1. Master style prompt

Prepend this to every asset prompt. Keep the wording identical across the
project.

```text
STYLE: dark gothic illustrated fantasy game art, straight top-down orthographic view
(camera looking straight down, we see tops of heads, shoulders, roofs and tree canopies),
thick hand-inked near-black outlines (#0d0b0a) with slight brush wobble, an extra bold
silhouette outline around the whole subject, flat desaturated base colours, one hard-edged
cel shadow on the lower-right side (key light from the top-left), chunky diagonal ink
hatching inside the deepest shadows, a thin cold highlight sliver on top-left edges,
warm orange forge rim light (#ff8a2a) on the bottom edges of skin, leather, metal and wood,
cold blue moonlight rim (#7f9cc0) on foliage, stone and roofs, stark value contrast,
muted palette of earthy browns, slate greys and dark green-greys with saturated accents
only in fire, gold, gems and red cloth, subtle film grain texture, gritty, weathered,
lived-in medieval fantasy, exaggerated heavy top-heavy silhouettes (broad shoulders,
small heads), 2D game asset, clean readable shapes
```

### Master negative prompt

```text
3/4 view, isometric, side view, perspective, tilted camera, horizon, photorealistic,
3D render, CGI, smooth gradients, airbrush, soft painterly blending, glossy plastic,
anime, chibi, cute, pastel colours, bright saturated palette, neon, thin lines,
sketchy unfinished lines, lineless, watercolour bleed, blurry, depth of field,
lens flare, bloom haze, text, letters, watermark, signature, logo, UI elements,
frame, border, cropped subject, multiple subjects, duplicate limbs, extra fingers,
background scenery (for sprites), checkerboard pattern, white halo, drop shadow box
```

---

## 2. Consistent artistic & technical requirements

| Requirement | Value |
|---|---|
| Camera | Straight top-down orthographic for world assets; front view for armour icon; 45° diagonal for weapon icons; 3/4 bust only for dialogue portraits |
| Character facing | South (toward bottom of image) by default |
| Key light | Top-left, cold; shadow falls bottom-right |
| Warm rim | `#ff8a2a`, on south/bottom edges of warm materials, ≤50 % strength in sprites |
| Cold rim | `#7f9cc0`, on foliage, stone, roofs, water |
| Outline | ~5 px inner ink + ~4 px outer silhouette at 512 px; scale proportionally (≈1 % + 0.8 % of canvas width) |
| Ink colour | `#0d0b0a` (no pure black, no coloured lines) |
| Hatching | Diagonal (≈ −35°), parallel, evenly spaced (~7 px at 512), only in the deepest shadow band |
| Palette | Locked to README palette table; fire/gold/gem/red cloak are the only saturated hues |
| Proportions | Shoulders 1.14×, head 0.90×, belly 1.08× versus neutral design |
| Texture | Fine monochrome grain, no large noise blotches |
| Sprite canvas | 512×512 masters, transparent, subject centred, ≥24 px padding |
| Compositions | 1920×1080, night/dusk, heavy vignette |

---

## 3. Transparent-background & framing rules

- Ask for **"isolated on a plain flat background"** (pure `#00ff00` or `#ff00ff`
  if the model cannot output alpha), then key it out; never accept a generated
  checkerboard.
- If the model supports alpha (or background removal), require a **straight
  alpha PNG**; after removal, verify there is no light halo — the 4 px ink
  silhouette border should sit directly against transparent pixels.
- Subject fully inside the canvas: **≥ 24 px padding** on all sides at 512 px,
  nothing cropped (hammer head, sword tip, shield edge included).
- Ground shadow: only a **soft dark ellipse directly under the subject**
  (black, ~45 % opacity), offset slightly to the bottom-right; it may be removed
  in post and replaced by an in-engine shadow.
- Characters: feet / ground contact at the centre of the lower third
  (around y ≈ 330–360 of 512), so the pivot convention in `naming_guide.md` holds.
- Icons: centred on the canvas centre, occupying ~80 % of the shorter side.

---

## 4. Individual prompts

Each prompt = **master style prompt + subject prompt below**. Negative prompt =
master negative + the subject-specific additions.

### 4.1 `blacksmith.png` — protagonist sprite

**Purpose:** reference sprite and model sheet anchor for the player character;
defines scale for every other character.
**Canvas:** 512×512, transparent, facing south, ≥24 px padding.

```text
[MASTER STYLE PROMPT]
SUBJECT: a single older heavyset retired adventurer who is now the village blacksmith,
seen from directly above, facing down (south). Bald, scarred scalp with a grey hair
fringe at the back of the head, a black eyepatch strap crossing the scalp diagonally.
A huge grey braided beard with a gold beard-ring projecting forward over a big round
belly. Brown leather apron with a front pocket and scorch marks, belt with an iron buckle
and a small pouch, apron straps crossing on his back between the shoulder blades.
A single old dented steel adventuring pauldron on his left shoulder (viewer's right).
Leather bracers, bare hairy muscular forearms. A heavy iron sledgehammer hanging from his
right hand (viewer's left), head pointing down. Iron tongs hanging at his left hip.
Toes of worn boots peeking out beneath the belly. Broad, heavy, top-heavy silhouette:
shoulders very wide, head small. Warm orange forge rim light along the bottom edges of
beard, belly, apron and hammer. Soft dark ground shadow ellipse under him.
Isolated on a plain flat background, centred, full figure visible.
```

Negative additions: `face visible, eyes, front view, standing pose seen from the front, thin, young, hair on top of head, two pauldrons, shield`

Consistency notes: this sprite defines the **scale reference** — his shoulder
width (~62 % of canvas) and footprint (~36 % of canvas width) are the yardstick
for all characters. Keep the pauldron on his left and hammer on his right in
every direction sheet.

### 4.2 `adventurer.png` — visiting adventurer

**Purpose:** demonstrates the shared proportion system on a slimmer body and
the shoulder-line identity of adventurers.
**Canvas:** 512×512, transparent, facing south.

```text
[MASTER STYLE PROMPT]
SUBJECT: a single travelling adventurer seen from directly above, facing down (south),
same scale and proportion system as a heavyset blacksmith but slimmer and more athletic.
Dark hair tied in a ponytail running down the back, a cloth headband, a round wooden shield
with an iron boss and iron rim slung on the back over a deep red cloak, steel pauldrons on
both shoulders, brown leather jerkin and leather bracers. A drawn steel longsword held in
the right hand (viewer's left), point forward (toward the bottom of the image). A dagger
sheathed at the left hip. Boots peeking out at the bottom. Warm orange rim light on
the forward edges of the pauldrons, sword and jerkin. Soft dark ground shadow ellipse.
Isolated on a plain flat background, centred, full figure visible.
```

Negative additions: `face visible, helmet covering ponytail, bow, two weapons drawn, bulky belly, beard`

Consistency notes: same outline weight and same head size as the blacksmith;
shoulders narrower than his (~50 % of canvas). Cloak red is `#521c19` base —
the only large saturated area allowed on a character.

### 4.3 `sword.png` — inventory icon

**Purpose:** template for all weapon icons.
**Canvas:** 512×512, transparent, 45° diagonal, tip to top-right, centred.

```text
[MASTER STYLE PROMPT — but replace the camera line with: inventory icon, flat 2D view]
SUBJECT: a single ornate longsword as a game inventory icon, laid diagonally at 45 degrees
with the tip pointing to the top-right corner and the pommel at the bottom-left.
Steel blade with a deep central fuller engraved with faintly glowing orange runes,
a curled gold crossguard with a central red faceted gem, dark leather-wrapped grip with
cross-binding, gold pommel set with a smaller red gem. Thick ink outline, hard cel shadow
on the lower-right side of the blade, ink hatching in the darkest shadow, a thin cold
highlight line along the upper-left blade edge. Isolated on a plain flat background,
centred, the whole sword visible with padding.
```

Negative additions: `hand holding sword, scabbard, multiple swords, perspective foreshortening, wall mount, curved sabre`

Consistency notes: every weapon icon uses the same 45° diagonal, the same
light direction and outline weight; length ≈ 90 % of the canvas diagonal.

### 4.4 `armor.png` — inventory icon

**Purpose:** template for armour/body-equipment icons.
**Canvas:** 512×512, transparent, front view, centred.

```text
[MASTER STYLE PROMPT — but replace the camera line with: inventory icon, flat 2D front view]
SUBJECT: a single suit of steel plate body armour as a game inventory icon, front view,
no wearer. Breastplate with a raised central ridge and an embossed gold anvil emblem,
a gorget at the neck, three-lame articulated pauldrons on both shoulders, faulds below
the waist and two hanging tassets, brown leather side straps with iron buckles, rows
of round rivets. Dark steel with a thin cold highlight on the upper-left edges, hard
shadow and ink hatching on the lower-right, a faint warm orange rim on the bottom edges.
Isolated on a plain flat background, centred, symmetrical, entire armour visible with padding.
```

Negative additions: `person wearing it, head, helmet, arms, mannequin, stand, asymmetrical`

Consistency notes: armour icons are the one class drawn in **front view**;
keep the anvil emblem as the smithy's maker's mark on crafted gear.

### 4.5 `tree.png` — environment sprite

**Purpose:** template for foliage and large environment props.
**Canvas:** 512×512, transparent, straight top-down.

```text
[MASTER STYLE PROMPT]
SUBJECT: a single deciduous tree seen from directly above: a round, slightly irregular
canopy made of 6 to 9 overlapping clumps of foliage, each clump with its own ink outline,
hard shadow on its lower-right side and ink hatching where clumps overlap. Dark muted
green-grey leaves (#2a3b2e base, #4f6a4c lights), a few olive clumps for variation,
a cold blue moonlight rim on the upper-left edges of the clumps. The base of a gnarled
trunk and a root just peeking out from under the bottom-right of the canopy. A soft dark
cast shadow offset toward the bottom-right. Isolated on a plain flat background, centred.
```

Negative additions: `side view of trunk, visible branches from the side, lollipop tree, pine tree, bright green, flowers, fruit`

Consistency notes: canopy fills ~85 % of the canvas; cold rim, never warm rim,
on foliage. Create variants by re-arranging clumps, not by changing style.

### 4.6 `town_view.png` — village overview

**Purpose:** key art for gameplay mood and map layout; reference for tile and
building scale.
**Canvas:** 1920×1080, opaque, straight top-down.

```text
[MASTER STYLE PROMPT]
SUBJECT: a small medieval fantasy village at night seen from directly above as a 2D game
map. Centre: a cobbled crossroads square with a stone well and a covered market stall.
South-west of the square: the blacksmith workshop — stone walls, dark slate roof,
a chimney with rising smoke, an open forge yard with an anvil, a brightly glowing forge,
a quench trough and a weapon rack; the forge casts a large warm orange pool of light.
North-east of the square: the inn "The Tipsy Wyvern", the largest building, L-shaped
with a red tiled roof, a stable and beer-garden tables, warm light spilling from windows
and door. Around: small cottages with slate and tile roofs, a small stone chapel,
wooden fences, crates and barrels, lanterns on posts making small warm pools. A stream
with a wooden bridge on the east side. Dense dark forest edge along the north and west.
Tiny villagers, the heavyset bald bearded blacksmith at his anvil, and an adventurer
with a round shield on the road. Cold blue-black ground, drifting cold fog, embers
rising from the forge, heavy dark vignette at the edges. Readable paths, clear
building footprints.
```

Negative additions: `isometric, perspective, daylight, sunny, birds-eye angle with walls visible, text labels, UI, map legend, compass rose`

Consistency notes: building roofs are seen flat from above (no walls visible
except a thin edge); characters at the same scale as the sprites (blacksmith
≈ 1.5 tiles wide). Keep at least 3 clear light pools: forge (largest), inn,
square.

### 4.7 `menu_screen.png` — main menu

**Purpose:** title screen and first impression; UI style reference.
**Canvas:** 1920×1080, opaque. Generate the background **without text**;
title and buttons are set in Godot with the fonts below.

```text
[MASTER STYLE PROMPT]
SUBJECT: main menu background for a dark fantasy blacksmith game: the village at night
from directly above, heavily darkened, with the blacksmith's forge yard glowing at the
lower-left third, sparks and glowing embers drifting upward across the whole image,
thick cold fog, very heavy vignette leaving the centre-left calm and dark enough for
a title and a vertical column of menu buttons. Moody, mysterious, warm fire against
cold darkness.
```

Negative additions: `text, title, letters, buttons, UI, characters close-up, bright centre`

Overlay (built in Godot, not generated): title "Embers of the Forgotten" in
Grenze Gotisch 800 with ember glow; buttons Continue / New Game / Load Game /
Settings / Credits / Quit in Grenze 600 (normal/hover/pressed/disabled per
README); version label bottom-right in Alegreya Sans 400, `#6e6a64`.

### 4.8 `font_reference.png` — typography sheet

**Purpose:** UI/typography reference. This is a **layout task, not a generation
task** — build it in Godot or a design tool with the real fonts. An image model
may only be used for the panel texture.

```text
[MASTER STYLE PROMPT — texture only]
SUBJECT: a seamless dark UI panel texture, worn dark leather and iron, near-black
(#0b0c10 to #2a2420), subtle grain and scratches, thin riveted iron border, no text.
```

Negative additions: `text, letters, symbols, bright colours, ornament overload`

Sheet content: title sample; H1/H2 headings; UI paragraph; dialogue sample with
speaker name; buttons in four states; item names in the six rarity colours
(Common `#d8d4cc`, Magic `#7b93ff`, Rare `#f2d65a`, Legendary `#ff8a30`, Unique
`#c9a35a`, Set `#45d46e`); stat block with tabular figures.

---

## 5. Keeping consistency across additional assets

### Seed & reference strategy

1. Generate the **blacksmith** first, iterate until approved, then lock it as the
   primary style reference (image prompt / IP-adapter / style reference at
   ~0.5–0.7 weight).
2. Fix a **project seed per asset class** (characters, icons, environment) and
   record it with each accepted output in `art_log.csv`.
3. Build a small **style LoRA / fine-tune** (20–40 approved, cleaned images)
   once the first ~30 assets exist; from then on, generate with the LoRA plus
   the master prompt.
4. For direction sheets (N/E/W), use the approved S sprite as image reference
   and change only the facing sentence.

### Locks

| Lock | Rule |
|---|---|
| Palette | Quantise/remap every output to the README palette (allow ±1 step); use a Krita/Aseprite palette file `gothic_noir.gpl` |
| Outline weight | 5 px inner + 4 px outer at 512 px master; re-ink in post if the model drifts |
| Light | Key light top-left; shadow bottom-right; warm rim bottom; cold rim on environment |
| Scale | Every character checked against `chr_scale_reference_sheet.png` (blacksmith, adventurer, villager, child, door, barrel, tile grid) |
| Grain | Removed from sprites in post if the engine adds screen grain (avoid double grain) |

### Post-processing checklist

- [ ] Background removed; straight alpha; no light/coloured halo (inspect on black and on magenta)
- [ ] Outline continuous; outer silhouette border present and ~4 px at 512
- [ ] Palette remapped; no off-palette saturated colours
- [ ] Light direction correct; warm rim only on warm materials
- [ ] Hatching only in deep shadows, consistent angle (~ −35°) and spacing
- [ ] Top-down view verified (no faces, no side-visible walls)
- [ ] Facing south (sprites); pivot point at ground contact
- [ ] Canvas size and padding correct; subject centred
- [ ] Greyscale check: silhouette readable at 25 % size (≈128 px)
- [ ] Exported per `naming_guide.md` (name, size, folder)

### Fill-in-the-blank template for new assets

```text
[MASTER STYLE PROMPT]
SUBJECT: a single {asset type, e.g. "wooden cart loaded with ore"} seen {from directly above |
as an inventory icon at a 45 degree diagonal | as an inventory icon in front view},
{facing down (south) — characters only}.
Key features: {3–6 concrete visual features, top-down visible parts first}.
Materials: {e.g. dark weathered wood, iron bands, leather straps} in muted tones;
saturated accent only on {fire | gold | gem | red cloth | none}.
Lighting: hard shadow lower-right, ink hatching in deepest shadow,
{warm orange forge rim on the bottom edges | cold blue moon rim on upper-left edges}.
Scale: {e.g. "about as wide as the blacksmith's shoulders" / "two tiles wide"}.
Isolated on a plain flat background, centred, entire subject visible with padding.

NEGATIVE: [MASTER NEGATIVE] + {subject-specific exclusions}
CANVAS: {512x512 transparent | 1024x1024 transparent | 1920x1080 opaque}
FILE: {name per naming_guide.md}
```
