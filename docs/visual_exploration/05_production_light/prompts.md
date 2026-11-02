# 05 · Production-Light Indie Fantasy — "Anvil & Ale" · Prompts

Prompts for producing production-quality versions of the eight example graphics with an image
model, or for briefing an artist. The examples in this folder are procedural vector mock-ups
(see [README → Rendering note](README.md#rendering-note-read-first)); they are the visual target
for palette, shading and proportion.

No reference images were found in the repository. If the four references from the brief are
supplied later, re-check these prompts (especially character descriptions and palette) against
them and attach them as image references.

**Practical note:** this style is easier to produce exactly by hand in a vector tool than with a
diffusion model, which tends to add gradients and texture. Treat model output as a draft: trace
or vectorise it and quantise to the palette (see the post-processing checklist below).

---

## 1. Master style prompt

Prepend to every prompt.

```
Production-light indie fantasy 2D game art, clean flat vector illustration, NO outlines,
flat colour fills with exactly two tones per material: a base colour plus one hard-edged
darker shadow shape on the bottom-right side of every form (single light source from the
top-left), no gradients, no textures, no noise, no brush strokes, crisp anti-aliased edges.
Simple geometric shape language built from ellipses, rounded rectangles and soft blobs,
slightly irregular hand-placed geometry. Friendly chunky proportions: slightly large heads,
narrow compact shoulders. Medium-saturation warm daylight palette: warm skin #eab08a, linen
#dcc69a, leather #94603a, steel #b4bfc9, gold #eab448, teal cloak #3f7a74, terracotta
#c25a42, slate blue #5e7891, grass #94bc62, foliage #6ea552, stone #c0b8aa, water #6fb7c9;
amber accent #f2a33a used sparingly for fire and gold. Flat semi-transparent dark plum
(#2e2a35) ground shadows with no blur. Small medieval fantasy village, D&D-inspired, warm,
lived-in, characterful. Straight top-down orthographic view (camera looking straight down)
for world assets. Cohesive game asset, clean and readable at small sizes.
```

### Master negative prompt

```
outline, black lines, ink lines, line art, gradient, soft shading, airbrush, glow, bloom,
texture, paper texture, grain, noise, hatching, painterly, watercolour, brush strokes,
photorealistic, 3D render, isometric, 3/4 view, side view, perspective, vanishing point,
pixel art, dithering, chibi exaggeration, anime, glossy specular highlights, bevel, emboss,
drop shadow with blur, vignette, text, watermark, signature, logo, frame, busy background,
cropped subject, multiple subjects, extra limbs, extra fingers
```

---

## 2. Individual prompts

All world sprites: straight top-down, facing **south (down-screen)**, light top-left, shadow
bottom-right. Character and prop scale is relative to the blacksmith (see §4).

### 2.1 `blacksmith.png` — protagonist sprite

**Purpose:** key art for the protagonist; reference for the rig and paper-doll layers.

```
[MASTER] Straight top-down view, camera directly above, of an older heavyset retired
adventurer who is now the village blacksmith, facing south (towards the bottom of the
image). We see the top of his head and his shoulders: bald scarred scalp with a grey hair
fringe at the back, a dark leather eyepatch strap crossing the head diagonally, a big grey
braided beard projecting forward (down-image) over a large round belly, a gold beard ring
on the braid. Leather apron (#7e5236) with a front pocket, belt with brass buckle and a
pouch, apron straps crossing on his back, a single dented old steel adventuring pauldron
on his left shoulder only (viewer's right), leather bracers, bare muscular forearms, a
heavy sledgehammer hanging from his right hand (viewer's left) with its head resting
below, tongs hanging at his left hip, boot toes peeking out under the belly. Flat oval
plum ground shadow at 22% opacity beneath him. Centered, isolated, transparent background.
```

- **Negative:** master negative + `face visible from front, eyes looking at camera, symmetrical shoulders, two pauldrons, standing pose seen from side`
- **Framing:** 1:1, export 512×512 PNG RGBA, transparent. Character fills ~70 % of height incl. hammer; feet centre at ~(256, 400).
- **Consistency:** head 1.16× / shoulders 0.96× baseline; single pauldron and beard ring are his signature shapes — never omit. Beard uses `beard` tones (#dcd6cb / #b4ab9c), not hair tones.

### 2.2 `adventurer.png` — adventurer sprite

**Purpose:** proves the shared proportion system on a slimmer body; template for visitors.

```
[MASTER] Straight top-down view, camera directly above, of a young adventurer facing south.
Same scale and head size as the blacksmith but a slimmer, athletic build. Visible from
above: top of head with a cloth headband and a ponytail falling down the back, a round
wooden shield with a steel boss slung on the back over a teal cloak (#3f7a74), steel
pauldrons on both shoulders, leather jerkin and leather bracers, a drawn straight sword
held point-forward (down-image) in the right hand (viewer's left), a dagger sheathed at the
left hip, boot toes visible. Flat plum ground shadow. Centered, isolated, transparent
background.
```

- **Negative:** master negative + `bow, helmet covering head, cape billowing, action pose, motion blur`
- **Framing:** 512×512 RGBA, transparent; same feet anchor as the blacksmith.
- **Consistency:** reuse exact head, hand and boot shapes from the blacksmith; shield disc is the identifying silhouette.

### 2.3 `sword.png` — inventory icon

**Purpose:** reference for all weapon icons.

```
[MASTER] Inventory icon of a fantasy longsword, single object, laid diagonally at 45
degrees with the tip pointing to the top-right corner and the pommel to the bottom-left.
Steel blade (#b4bfc9 base, #7f8c99 shadow) with a central fuller drawn as a darker line,
curled gold crossguard (#eab448) with a small blue gem in the centre, brown leather-wrapped
grip with simple diagonal wrap lines, round gem pommel. Flat two-tone shading, hard shadow
on the bottom-right edges. Centered with even margin, transparent background.
```

- **Negative:** master negative + `hand, character, scabbard, ground shadow, glowing blade, runes, background plate`
- **Framing:** 512×512 RGBA, subject ~80 % of the diagonal, 10 % margin; downscale to 128 and 64.
- **Consistency:** all weapon icons use the same 45° tip-top-right orientation and margin.

### 2.4 `armor.png` — inventory icon

**Purpose:** reference for armour and equipment icons.

```
[MASTER] Inventory icon of a steel plate armour set seen from the front, single object:
breastplate with a central vertical ridge and a small gold anvil emblem on the chest,
gorget at the neck, three-lame layered pauldrons on both shoulders, faulds below the waist,
two tassets hanging over the thighs, brown leather side straps with small buckles, round
rivets. Steel (#b4bfc9) with one hard shadow tone (#7f8c99) on the bottom-right of each
plate, gold (#eab448) emblem. Centered, symmetrical, transparent background.
```

- **Negative:** master negative + `person wearing it, helmet, mannequin, stand, chainmail texture, scratches, rust`
- **Framing:** 512×512 RGBA, ~80 % height, centred.
- **Consistency:** icons are the only front-view assets; plates read as stacked rounded rectangles.

### 2.5 `tree.png` — environment sprite

**Purpose:** reference for all vegetation.

```
[MASTER] Straight top-down view of a deciduous tree canopy seen from directly above: a
roughly round crown made of about fifteen overlapping rounded foliage clusters, each
cluster a flat green blob (#6ea552) with a hard darker shadow crescent (#4a7c40) on its
bottom-right, clusters nearer the top-left drawn on top, a few small pale-green sunlit
leaf spots (#8cc066), a short brown trunk base peeking out at the bottom edge. Flat plum
cast shadow (#2e2a35, 22% opacity, no blur) the same shape as the canopy, offset towards
the bottom-right. Centered, transparent background.
```

- **Negative:** master negative + `trunk seen from side, branches, side view, individual leaves, flowers`
- **Framing:** 512×512 RGBA; canopy ~70 % of width; trunk base at ~(256, 350) is the pivot.
- **Consistency:** variants change cluster count and palette (`foliage2` #96a848), never the shading method.

### 2.6 `town_view.png` — village overview

**Purpose:** establishes world layout, scale and tile-friendliness.

```
[MASTER] Straight top-down orthographic view of a small medieval fantasy village in
neutral daylight, laid out on a clear tile grid, modular buildings. Central crossroads
square of sandy road (#d4bf92) with a round stone well and a market stall with a striped
awning. South-west of the square: the blacksmith workshop with stone walls and a slate-blue
roof (#5e7891), a chimney, an open forge yard with an anvil, a glowing forge (#f2a33a), a
quench trough of water and a weapon rack. North-east: the inn "The Tipsy Wyvern", the
largest building, L-shaped with terracotta roof (#c25a42), a stable and beer-garden tables.
Several small cottages, a small stone chapel, wooden fences, crates and barrels. A stream
(#6fb7c9) with a wooden bridge on the east side. Forest edge of round tree canopies along
the north and west. Tiny villagers, the heavyset blacksmith at the forge and an adventurer
walking in. Roofs seen flat from above with ridge lines, all shadows cast to the
bottom-right, flat grass (#94bc62).
```

- **Negative:** master negative + `isometric buildings, visible building walls on the south side, perspective roofs, night, fog, clouds over the map`
- **Framing:** 16:9, 1920×1080, opaque, no UI. Grid: 40 × 22.5 tiles of 48 px at 1× art scale (an overview shot; in-game the 1280×720 base view shows ~27 × 15 tiles).
- **Consistency:** character and prop scale must match §4 (a character ≈ 1 tile wide); all buildings snap to whole tiles.

### 2.7 `menu_screen.png` — main menu

**Purpose:** UI look, button states and title treatment.

```
[MASTER] Video game main menu screen, 1920x1080. Background: a simple flat top-down
view of the village (smithy and inn roofs, trees) dimmed with a dark plum
overlay. Left-centre: a clean rounded flat panel in dark plum (#2e2a35, 92% opacity). Title
"Anvil & Ale" in a friendly slab serif (Bree Serif style), cream (#eee0bc) letters with a
flat hard offset shadow to the bottom-right, ampersand in amber (#f2a33a). Below it a
vertical stack of flat rounded buttons: Continue (highlighted amber fill with dark text),
New Game, Load Game, Settings, Credits, Quit (plum-grey #3a3542 fill with cream text).
Small version label "v0.1.0" bottom-right in grey sans-serif.
```

- **Negative:** master negative + `ornate frame, metallic buttons, beveled buttons, glossy UI, gothic lettering, script font, misspelled text`
- **Framing:** 1920×1080 opaque. Image models misspell text — generate the background only and set all text in Godot (or in a vector tool) with the real fonts.
- **Consistency:** button radius 6–8 px; only one amber element besides the title ampersand.

### 2.8 `font_reference.png` — typography sheet

**Purpose:** reference for the Theme resource; best built as a vector/Godot layout, not generated.

```
[MASTER] Typography reference sheet for a fantasy game UI on dark plum (#2e2a35) background,
1920x1080, clean grid layout. Sections: game title "Anvil & Ale" in Bree Serif cream with
flat offset shadow; heading samples in Bree Serif; UI body text and a dialogue box sample
in Source Sans 3; a row of flat rounded buttons in four states (normal, hover, pressed,
disabled); a list of item names in rarity colours: Common #f2f0ec, Magic #6ea4ff, Rare
#ffd84a, Legendary #ff9634, Unique #cfa66a, Set #5cd274; a stats table with right-aligned
tabular numbers.
```

- **Negative:** master negative + `handwritten fonts, decorative borders, parchment`
- **Framing:** 1920×1080 opaque. Build with real fonts; use the prompt only to brief layout.
- **Consistency:** exactly two families (Bree Serif, Source Sans 3).

---

## 3. Consistent artistic & technical requirements

| Requirement | Rule |
|-------------|------|
| View | Straight top-down for all world assets; front view only for inventory icons and UI |
| Light | Single light from top-left; every shadow shape bottom-right |
| Tones | Exactly two per material (base + shadow); light tone only for tiny accent spots |
| Outlines | None. Interior details as round-capped strokes in the material's shadow tone |
| Gradients / texture | None, anywhere, including UI |
| Ground shadows | Flat `#2e2a35` at 22 % opacity, no blur |
| Palette | Locked to the hex list in §5; accent amber reserved for fire/gold/focus |
| Proportions | Head 1.16×, shoulders 0.96× of shared template; smith is the widest character |
| Edges | Anti-aliased edges, but no intermediate colours inside shapes (palette-swap safe) |
| Output | PNG RGBA (sprites/icons) or opaque PNG (scenes), sRGB, no embedded colour profile shifts |

## 4. Transparent background & framing rules

- Sprites and icons: **true alpha**, no white/checker background, no halo. If the model cannot
  output alpha, generate on flat `#ff00ff`, key it out, then remove fringe (defringe 1 px).
- One subject per image, fully in frame, ≥ 8 % margin on every side.
- Characters: feet centre on a fixed anchor (in 512 px masters: x = 256, y ≈ 400); facing south.
- Trees/props: trunk base or footprint bottom-centre on the anchor.
- Icons: centred, ~80 % fill, weapons 45° tip top-right.
- Scale reference: the blacksmith's shoulders ≈ 1 tile (48 px) wide in game; a barrel ≈ 0.75
  tile; a door ≈ 1 tile; a tree canopy 2–3 tiles.

---

## 5. Keeping consistency across new assets

### Reference / seed strategy
- Keep a **style board** of approved assets (start with the eight examples) and attach 2–3 of
  them as image references (IP-Adapter / style reference / "--sref") on every generation.
- Fix the seed per asset family (e.g. all villagers from one seed range); log seed, model,
  sampler and prompt in a sidecar `.txt` next to each master.
- Generate characters as a **turnaround sheet** (S, N, W in one image) so they share details.

### Palette lock

```
skin #f5c7a0 #eab08a #c98264 | beard #f1eee8 #dcd6cb #b4ab9c | hair #d8d2c6 #b4ab9c #8a8274
shirt #eee0bc #dcc69a #b49e72 | apron #9c6a48 #7e5236 #5c3a26 | leather #b4784c #94603a #6a4229
strap #6a4632 #5a3a28 #3e281c | metal #dfe5ea #b4bfc9 #7f8c99 | gold #f6cf62 #eab448 #c08a2e
cloak #4f8f88 #3f7a74 #2c5a56 | tunic #e07450 #cc5e3e #9c432c | boot #6e4c3a #5a3d2e #3e2a20
wood #c4946a #a87a52 #7c5838 | foliage #8cc066 #6ea552 #4a7c40 | foliage2 #b4c25a #96a848 #6a7e36
grass #a4c870 #94bc62 #7aa452 | road #e2d0a6 #d4bf92 #b49e74 | roof_a #d66a4e #c25a42 #963f2e
roof_b #6e88a2 #5e7891 #465d73 | stone #d6d0c4 #c0b8aa #958c7e | water #80c4d4 #6fb7c9 #4f97ad
gem #7ad0e0 #46a8c8 #2a7894 | fire #fbe6a0 #f2a33a #d0662a
UI #2e2a35 · panel #3a3542 · accent #f2a33a · accent light #f7d27a
```

New materials need a new 3-tone role added to this list (and to `styles.py`) — never ad-hoc colours.

### Two-tone rule
Base + one hard shadow per shape. Need more form? Split the shape, don't add a tone.

### Shape-language rules
- Build from ellipses, rounded rectangles and low-wobble blobs; corner radii generous.
- Reuse primitives: one head, one hand, one boot shape across all humanoids.
- Every character has one forward-projecting element (beard, weapon, toes) to show facing.
- Every important character/building has one signature shape.

### Light direction
Top-left, fixed. Check every asset by flipping attention to the bottom-right edges: all
shadows there? If mirrored for the east direction, the shadow side must be **re-drawn or
re-shaded**, not mirrored (mirroring moves shadows to the bottom-left). In practice: mirror
the base shapes, regenerate the shadow crescents.

### Scale reference sheet
Maintain `scale_reference.png`: the smith, adventurer, a villager, a barrel, a door, a tree and
a 48 px grid side by side. Every new asset is checked against it before export.

### Post-processing checklist
1. Background removed, alpha clean, no halo.
2. Vectorise (Inkscape *Trace Bitmap → Multiple scans → Colours*, or Vectorizer.ai) or redraw.
3. Remove gradients/texture; merge near-identical colours.
4. **Quantise to the palette**: snap every fill to the nearest locked hex (script or
   Affinity/Inkscape palette replace); max 2 tones per material.
5. Check light direction and shadow placement.
6. Check scale against the reference sheet; set pivot/anchor.
7. Export PNG at the sizes in [`naming_guide.md`](naming_guide.md); keep the SVG master.
8. Name according to the naming guide.

### Fill-in-the-blank template

```
[MASTER] Straight top-down view, camera directly above, of [SUBJECT], facing south.
Visible from above: [TOP-OF-HEAD / ROOF / CANOPY FEATURES]. Wearing / made of
[MATERIALS using role names + base hex]. Signature shape: [ONE MEMORABLE ELEMENT].
Holding / attached: [PROPS, which side — viewer's left/right]. Scale: [n] tiles wide
relative to a 48 px tile where the blacksmith is 1 tile wide. Two tones per material,
shadow bottom-right, no outlines, no gradients. Flat plum ground shadow at 22% opacity.
Centered, isolated, transparent background.
Negative: [MASTER NEGATIVE], [SUBJECT-SPECIFIC EXCLUSIONS]
```
