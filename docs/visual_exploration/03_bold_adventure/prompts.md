# 03 — Bold Readable Adventure Sim · Prompts

Reusable prompts for producing production-quality art in the "Forged Fortunes" direction with an image-generation model, or for briefing an artist. See [`README.md`](README.md) for the full style description and palette.

> **Context.** The example images in this folder are procedural vector mock-ups (Python-generated SVG rasterised with headless Chromium) because no image model was available when they were made. Use them as **composition and palette references** for img2img / reference-image workflows, not as quality targets. No reference images from the original brief were found in the repository; if they are supplied later, re-check these prompts (especially character details and mood) against them.

---

## Master style prompt

Prepend this to every asset prompt.

```text
Bold readable fantasy adventure game art, stylised 2D, confident uniform dark navy outlines (#1c1a2e)
with a noticeably thicker outer silhouette contour, flat saturated base colours with exactly one
hard-edged cel shadow band and one hard-edged highlight band, single light source from the top-left,
shadows tinted navy-blue rather than grey or black, crisp clean vector edges, no texture, no gradients,
vibrant but controlled palette (warm orange leather, cobalt blue cloth, tomato red cloth, cool steel,
rich gold, lime-green foliage), expressive characters with slightly enlarged heads, distinct
silhouettes, chunky readable equipment, high gameplay readability, cheerful bright midday lighting,
medieval D&D-inspired fantasy village, polished indie game asset
```

## Master negative prompt

```text
photorealistic, 3d render, painterly, watercolour, oil paint, sketchy lines, rough or broken outlines,
varying line weight, soft gradients, airbrush, bloom, lens flare, blur, depth of field, noise, grain,
paper texture, film grain, pixel art, anime, chibi, isometric, 3/4 view, side view, perspective,
dark murky colours, desaturated, muddy browns, black shadows, grey shadows, neon, oversaturated,
text, watermark, signature, logo, frame, border, background clutter, cropped, cut off
```

---

## Consistent artistic & technical requirements

| Requirement | Value |
|-------------|-------|
| Camera | **Straight top-down** (orthographic, looking straight down) for world sprites: tops of heads, shoulders, roofs, canopies. Icons: front view or 45° diagonal. |
| Facing | Characters face **south** (towards the bottom of the image) by default |
| Outline | `#1c1a2e`, ~4 px at 512 px for parts, + ~4 px extra outer contour; ~2.5 px interior detail lines |
| Shading | Flat base + 1 hard shadow band (bottom-right) + 1 hard highlight (top-left). Nothing else. |
| Light | Top-left, bright midday; cast shadows toward bottom-right, hard-edged, navy at ~28 % opacity |
| Palette | Only ramps from the README palette table; new materials need a light/base/shadow ramp with navy-shifted shadow |
| Proportions | Head 1.12×, shoulders 1.04×, belly 1.0× of a neutral design; props ~1.2–1.4× oversized |
| Master size | 512×512 for sprites/icons; 1920×1080 for scenes and UI |
| Detail | Readable at 128 px: if a detail disappears at 1/4 size, enlarge or remove it |
| Mood | Warm, characterful, lived-in; darkness through lighting, not through palette |

### Transparent background & framing rules

1. Sprites and icons: **fully transparent background**, straight (non-premultiplied) alpha. If the model cannot output alpha, generate on flat `#ff00ff` magenta and key it out, then check outline edges for fringe.
2. Subject centred; nothing touches the canvas edge. Keep **≥ 24 px padding** at 512 (≥ 6 px at 128) — the outer contour must stay inside the canvas.
3. Characters: feet / ground-shadow centre at roughly x=256, y=330–360 of 512 so the pivot stays consistent.
4. Ground shadow is a separate flat navy ellipse (28 % opacity) — ideally generated or painted on its own layer so it can be removed in engine.
5. No text, no frames, no UI chrome, no background scenery in sprite/icon prompts.
6. One subject per image. No sprite sheets from the model — assemble sheets afterwards.

---

## 1. Blacksmith — `blacksmith.png`

**Purpose**: protagonist world sprite master; defines the scale reference for every character.

```text
[MASTER STYLE PROMPT], straight top-down view looking directly down on an older heavyset retired
adventurer who now works as a village blacksmith, facing south (toward the bottom of the image).
We see: bald scarred scalp with a fringe of grey hair at the back, an eyepatch strap running across
the top of the head, a big grey braided beard with a chunky gold beard-ring projecting forward over a
large round belly, orange-brown leather apron with a front pocket and scorch marks, belt with brass
buckle and pouch, apron straps crossing on his back, one battered old steel adventuring pauldron on
his left shoulder, leather bracers, bare hairy forearms, a heavy sledgehammer hanging from his right
hand (viewer's left), blacksmith tongs at his left hip, boot toes peeking out under the belly,
flat navy ground shadow ellipse beneath him. Wide sturdy silhouette, expressive, confident.
Transparent background, centred, full figure, 512x512.
```

**Negative**: master negative + `face visible, front view, eyes, young, thin, muscular bodybuilder, helmet, full plate armour, two pauldrons`.
**Framing**: 512×512, transparent, body ~60 % of canvas width incl. hammer, feet centre ≈ (256, 345), ≥ 24 px padding.
**Consistency notes**: this image is the **scale anchor** — save it as the reference for all character generations. Gold ring, eyepatch strap and single pauldron are identity markers; never drop them. Apron uses the `apron` ramp (`#e88a44 / #c0602a / #7c3812`).

## 2. Adventurer — `adventurer.png`

**Purpose**: typical customer/NPC adventurer; tests the proportion system on a slimmer build.

```text
[MASTER STYLE PROMPT], straight top-down view looking directly down on a young adventurer facing
south, same scale and proportion system as the blacksmith but slimmer build: hair tied in a ponytail
with a red headband, round wooden shield with a steel boss slung on the back over a cobalt-blue cloak,
steel pauldrons on both shoulders, brown leather jerkin and bracers, a drawn steel sword held point
forward (pointing down toward the viewer's south) in the right hand, a dagger at the left hip, boot
toes visible, flat navy ground shadow ellipse. Alert, heroic silhouette with the shield disc clearly
readable. Transparent background, centred, 512x512.
```

**Negative**: master negative + `face visible, helmet, heavy armour, bow, two swords, belly`.
**Framing**: as blacksmith; same head size in pixels as the blacksmith; shoulders ~15 % narrower.
**Consistency notes**: generate with the blacksmith image as a style/scale reference. Cloak `#2a6ee0`, headband/tunic accents `#e0403a`. The shield disc is the readable silhouette cue — keep it large.

## 3. Sword — `sword.png`

**Purpose**: inventory icon; template for all weapon icons and tier palette swaps.

```text
[MASTER STYLE PROMPT], inventory item icon of a fantasy longsword, laid on a 45-degree diagonal with
the tip at the top-right and pommel at the bottom-left, bright steel blade with a central fuller
engraved with small glowing runes, ornate curled gold crossguard with a magenta gem in the centre,
brown leather-wrapped grip with visible wraps, round gold pommel set with a gem, hard cel shading,
thick navy outline, no ground shadow. Transparent background, centred, 512x512.
```

**Negative**: master negative + `hand, character, scabbard, blood, broken blade, background, ground shadow`.
**Framing**: 512×512, transparent, sword spans corner to corner within 24 px padding (~80 % of the diagonal).
**Consistency notes**: all bladed weapon icons use the same 45° orientation (tip top-right). Metal ramp `#f6faff / #b4c2d8 / #5e6e8e`; keep blade, guard and gem as separate flat regions so palette swaps can retier them.

## 4. Armour — `armor.png`

**Purpose**: inventory icon for body armour; template for all armour icons.

```text
[MASTER STYLE PROMPT], inventory item icon of a fantasy steel breastplate armour set, front view,
symmetrical: breastplate with a raised central ridge and a gold anvil emblem in the middle, gorget at
the neck, three-lame articulated pauldrons on each shoulder, faulds below the waist, tassets hanging
over the thighs, brown leather side straps with buckles, rows of rivets, bright steel with hard cel
shadow band and highlight, thick navy outline. No body inside, no stand. Transparent background,
centred, 512x512.
```

**Negative**: master negative + `person wearing it, mannequin, armour stand, helmet, chainmail texture, rust`.
**Framing**: 512×512, transparent, ~80 % of canvas height, horizontally symmetrical, ≥ 24 px padding.
**Consistency notes**: the gold anvil emblem is the smithy's maker's mark — reuse it on crafted gear. All armour icons front view, same light direction.

## 5. Tree — `tree.png`

**Purpose**: environment prop; template for all trees and bushes.

```text
[MASTER STYLE PROMPT], straight top-down view of a deciduous tree canopy seen from directly above:
a rounded cluster of overlapping foliage blobs in lime and leaf green, each blob with a hard darker
green shadow band toward the bottom-right and a light highlight toward the top-left, navy outline
around the whole canopy, the base of the brown trunk just peeking out at the bottom, flat navy cast
shadow offset toward the bottom-right. Transparent background, centred, 512x512.
```

**Negative**: master negative + `side view, trunk visible full length, branches, individual leaves, flowers, fruit, background grass`.
**Framing**: 512×512, transparent, canopy ~80 % of width; cast shadow may extend to the bottom-right but stays within padding.
**Consistency notes**: canopy ramps `foliage` and `foliage2`; make 3–4 variants by rearranging clusters, not by changing style. Pivot = trunk base.

## 6. Town view — `town_view.png`

**Purpose**: establishes the in-game world view, density and colour balance.

```text
[MASTER STYLE PROMPT], straight top-down orthographic view of a small medieval fantasy village at
bright midday, game screenshot composition, 16:9. Centre: a crossroads square with a stone well and
a striped market stall. South-west of the square: the blacksmith workshop with stone walls, blue
slate roof, a chimney with puffs of smoke, and an open forge yard containing an anvil, a glowing
forge, a water quench trough and a weapon rack. North-east: the largest building, the L-shaped inn
"The Tipsy Wyvern" with red clay-tile roof, a stable and beer-garden tables. Around: cottages with
red-tile and blue-slate roofs, a small stone chapel, wooden fences, crates and barrels, dirt roads.
East side: a stream crossed by a wooden bridge. North and west edges: dense forest canopies. Tiny
villagers, the bald bearded blacksmith in the forge yard and an adventurer with a round shield on
the road. Crisp hard building shadows toward the bottom-right, high readability, every building
clearly distinct.
```

**Negative**: master negative (remove `background clutter`) + `isometric, perspective, walls visible from the side, night, fog, text labels`.
**Framing**: 1920×1080, opaque, no transparency. Implied tile grid of 64 px. This overview is zoomed out compared with gameplay, so figures are ≈ 48–64 px across rather than the 128 px in-game sprite canvas.
**Consistency notes**: red-tile (`roof_a`) and blue-slate (`roof_b`) roofs only; ground uses lower-saturation grass/road so characters pop. Use the generated scene for layout reference only — real levels are built from tiles in Godot.

## 7. Menu screen — `menu_screen.png`

**Purpose**: main-menu key art and UI mood.

```text
[MASTER STYLE PROMPT], game main menu screen, 1920x1080. Background: bright sunny top-down view of
the village slightly darkened behind the UI. Left: the title "Forged Fortunes" in classical Roman
capitals with flourishes, chunky gold fill, thick dark navy outline and a hard navy drop shadow.
Below it a vertical stack of big chunky rounded buttons with navy outlines and warm off-white text:
Continue, New Game, Load Game, Settings, Credits, Quit; the first button highlighted in gold.
Right side: the heavyset bearded blacksmith with his sledgehammer and the adventurer with shield and
sword shown large, same straight top-down style. Small version label "v0.1.0" bottom-right.
```

**Negative**: master negative (remove `text`) + `misspelled text, extra buttons, photographic background, thin elegant buttons`.
**Framing**: 1920×1080 opaque; keep the left 40 % calm for UI. Expect to **replace all text in Godot** — models misspell; the real menu uses Cinzel Decorative + Signika.
**Consistency notes**: button style = navy `#1c1a2e` panel, 4 px outline, gold `#ffcc33` hover. Characters must match the sprite masters.

## 8. Font reference — `font_reference.png`

**Purpose**: typography sheet. **Best made in Godot or a vector editor, not by an image model** — models cannot reproduce specific fonts reliably. Prompt for layout ideation only:

```text
Typography style sheet for a bold readable fantasy adventure game, 1920x1080, dark navy #1c1a2e
background. Sections: large title "Forged Fortunes" in gold classical capitals with navy outline and
hard drop shadow; headings in a bold humanist sans; UI body text; a dialogue box sample with speaker
name; four button states (normal, hover gold, pressed, disabled grey); item names in rarity colours
white, blue, yellow, orange, gold-brown and green each with a navy outline; large outlined numbers
for damage, gold and stats aligned in columns. Clean grid layout.
```

**Negative**: master negative (remove `text`) + `handwriting, script fonts, blurry text`.
**Framing**: 1920×1080 opaque.
**Consistency notes**: fonts Cinzel Decorative 900 (title) and Signika 400–700 (everything else); rarity hexes Common `#ffffff`, Magic `#4f8fff`, Rare `#ffe14a`, Legendary `#ff8a1f`, Unique `#e2b464`, Set `#46e070`.

---

## Keeping consistency across additional assets

### Reference-image & seed strategy

- Build a **style reference board**: blacksmith, adventurer, sword, tree and a crop of the town view. Feed 2–4 of them as image/style references (IP-Adapter, style reference, `--sref` or equivalent) on every generation.
- **Lock the seed** per asset family (characters / icons / environment) and change only the subject text. Record seed, model version, sampler and reference weights next to each accepted asset.
- For variants of one subject (tiers, colour swaps, poses) use **img2img from the accepted master** at low denoise (0.3–0.45) rather than new text-to-image runs.
- Consider training a small style LoRA once 30–50 cleaned assets exist.

### Palette lock

- After generation, **quantise to the README palette** (indexed colour or a palette-map script). Any colour not in a ramp must be justified and added to the table.
- Shadow colours must be the ramp's shadow hex — not a darkened base.

### Outline weight

- Re-ink or vector-trace so part lines are a constant 4 px and the outer contour a constant +4 px at 512. Models produce wobbly, variable lines; this is the step that most determines whether the style looks professional.

### Light direction

- Reject any image with light from anywhere other than the top-left or with soft shading. Cast shadows always to the bottom-right.

### Scale reference sheet

- Maintain `ref_scale_sheet.png`: blacksmith, adventurer, villager, a door, a barrel, a 64 px tile grid and a tree side by side at in-game scale. Every new world asset is checked against it before import.

### Post-processing checklist

1. Remove background → straight alpha; check for halos/fringe.
2. **Vector cleanup**: trace or redraw in a vector tool (Inkscape, Affinity, Illustrator); merge flat regions; enforce exactly 3 tones per material.
3. Snap colours to palette ramps.
4. Re-stroke outlines: 4 px parts, 2.5 px details, +4 px outer contour (or omit contour if the engine shader will add it).
5. Check padding ≥ 24 px and pivot position.
6. Downscale test at 128 px and 64 px: silhouette readable? Key identity marks visible?
7. Export master SVG + 512 PNG; export game sizes per [`naming_guide.md`](naming_guide.md).
8. Log prompt, seed and references in the asset's metadata/notes.

### Fill-in-the-blank template for new assets

```text
[MASTER STYLE PROMPT], [VIEW: straight top-down view looking directly down / inventory icon front view
/ inventory icon 45-degree diagonal, tip top-right] of [SUBJECT], [FACING: facing south], showing
[3–6 KEY READABLE FEATURES, largest first], materials: [MATERIAL ROLES from palette table, e.g. metal,
leather, gold], [POSE / STATE], [GROUND SHADOW: flat navy ground shadow ellipse / no ground shadow],
same scale as the blacksmith reference, transparent background, centred, [CANVAS: 512x512].
Negative: [MASTER NEGATIVE] + [SUBJECT-SPECIFIC EXCLUSIONS].
```
