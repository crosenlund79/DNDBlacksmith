# Ember & Ash — gameplay systems in the first build

> **Build status:** runs in Godot 4.3. It is covered by headless unit tests (`tests/test_runner.tscn`) and by rendered play-test phases (`tests/playtest.tscn`) that play the real game with synthetic input.

## The village of Brindlewick

The village is about 96 × 64 tiles of 64 px each. It is built from modular sprites:

- textured ground, roads and a cobbled square, plus a stream with a bridge
- 9 buildings, each with walls, doorways, a furnished interior and a roof that fades when you enter
- 4 exits: Whisperwood (W), Highmarsh Road (E), Ironroot Mine (N) and Barrow Fields (S)

| Place | What you can do |
|---|---|
| **Ironhand Forge** | A compact building of 13 rooms (see below). |
| **The Tipsy Wyvern** | Downstairs: common room with bar, hearth and tables; kitchen; Hilde's room. Upstairs, by the stairs: a landing, four guest rooms and the **Velvet Lantern** parlour with two private rooms, where adult companions offer conversation, rumours and a discreet fade-to-black evening. |
| **Pell's Provisions** | Aldric's shop, storeroom and living quarters. |
| **Village square** | Notice board (applicants, commissions, news), well and market stall. |
| **Other buildings** | Martha's cottage, Tobin's workshop, Jory's farm, and Eda's and Cooper's Row houses: each has a main room and a bedroom. The Chapel of the Dawn has a nave and a vestry. |

### Inside the Ironhand Forge

Rooms connect through doorways and short halls; there are no long empty corridors. Each discipline has its own floor, walls, clutter and light.

| Room | Contents |
|---|---|
| **Shopfront** | Counter, displays and the street entrance. Customers stay here. |
| **Stock hall** | The hub between the shop, the workshops and the private wing. |
| **Smithing Hall** | Forge, bellows, anvil, crucible, quenching trough and grinding wheel. Soot floor, tool wall and bar stock. |
| **Rune Room** | Five runecraft stations on slate, rune shelves and faint sigils. |
| **Alchemy Room** | Five alchemy stations, herb racks, bottle shelves and spill stains. |
| **Leather & Stitching** | Five stitching stations, hide racks, pattern board and thread. |
| **Material store** | Ore, coal and crates. |
| **Arcane Foundry** | Five arcane stations on violet stone. Locked until the Arcane Foundry upgrade, but you can walk in and inspect every station. |
| **Private quarters** | Living/dining room, a study whose desk ledger opens the books, a bedroom, a storeroom and a pantry. Customers never come back here. |

**Day and night:**

- The clock runs about 15 real minutes per day; Settings can change this.
- The light shifts through dawn, day, dusk and night.
- Lanterns, doors and windows light up at night; hearths and forges flicker.
- The music and ambience follow where you are and the time of day.

## Crafting: operations at physical stations

**Recipes are sequences of named operations, and each happens at a real station.** You walk from station to station, and a marker floats over the next one.

| Recipe | Operations | Stations |
|---|---|---|
| Leather belt | 1 | Stitching table |
| Iron longsword | 4 | Heat the billet (forge), draw out the blade (anvil), quench the edge, grind and sharpen |
| Steel longsword | 7 | Adds holding the heat at the bellows, normalising in the coals and wrapping the grip at the stitching table |
| Iron cuirass | 6 | Heat the plates, dish the breastplate, re-heat, planish and roll the edges, temper, rivet the leather straps |
| Ember runestone | 5 | Cleave, engrave, wash, tune, polish |
| Healing draught | 3 | Bruise, simmer, steep |

**What a recipe defines:**

- materials (inputs)
- the operation sequence and stations
- the number of checks per operation and their weight
- the required skills
- the difficulty and the material (iron, steel, silver, charged mithril, leather, ethereal thread…)
- the dice that decide its attributes

There are 24 recipes. They are data-driven in `tools/data/make_recipes.py`.

**Which disciplines are open:**

| Discipline | Status |
|---|---|
| Smithing | Open from the start |
| Runecrafting | Open from the start. Runewright's Tools widen its precision zones. |
| Alchemy | Open from the start. The Alchemist's Kit widens its precision zones. |
| Leatherwork | Open from the start. Enchanted stitching needs Enchanted Stitching 3. |
| Arcane Metalworking | Gated by the Arcane Foundry upgrade (Runecraft 3, mithril found, 600 g) |

**Beginner vs expert:**

- Each recipe's difficulty (plus its material's) is weighed against your skill. Above your level the zone narrows and the needle speeds up; below it, it widens and slows.
- Some recipes need a minimum level. For example, the Steel Bastard Sword needs Smithing 8.
- Experts earn less experience from routine work.
- Hirelings use the same skill framework.

**Socketing:** at the Rune Engraving Stand you can set finished runestones into existing equipment. This is distinct from arcane metal.

## Precision checks

- A needle sweeps the ring. You stop it with E, Space or a click.
- Quality is continuous: the closer to the zone's centre, the better. The centre gives 120%, the edge 70%, and misses fall towards 10%.
- Every check shows a grade and a coloured pip, plays a sound and triggers an effect at the station:
  - sparks at the anvil and grinding wheel
  - steam at the quench
  - bubbles at the cauldron
  - rune light
  - arcane flashes
- Each operation's checks are averaged. Operations are weighted, so drawing out the blade matters more than wrapping the grip.
- The final craftsmanship can exceed 100%.

## Dice

- **Digital:** animated rolls.
- **Physical:** roll real dice and enter the faces; values are validated.
- Before rolling, the dice panel tells you the worst and best rarity your craftsmanship allows.

**Dice by item type:**

| Item type | Dice |
|---|---|
| Weapons | edge d20, temper d12, fortune d100 |
| Armour | guard d20, temper d12, fortune d100 |
| Potions | potency d8, fortune d100 |
| Runestones | resonance d10, fortune d100 |
| Arcane blades | add spellweave d12 |
| Materials | purity d6 (a 6 adds a unit) |

- Stats = definition × craftsmanship × material × dice × skill. Craftsmanship dominates; dice move a stat by about ±15%.

**The results panel** shows:

- the item, its stats and rarity
- every operation with its score bar
- the final craftsmanship
- each die rolled
- a rarity bar with how the score was built
- the experience gained

The record is saved on the item. Reopen it from the stores with **Read the record of the work**.

## Items, rarity and legendaries

**Item types:** weapons, shields, metal and leather armour, helmets, boots, gloves, belts, rings, amulets, runestones, materials, alchemy, relics, containers, and one named unique and one set piece.

**Rarity colours:**

| Rarity | Colour |
|---|---|
| Common | white |
| Magic | blue |
| Rare | yellow |
| Legendary | orange, with a ★ |
| Unique | gold/brown |
| Set | green |

The colours apply to item names, slot borders and tooltips.

**Rarity from crafting:** score = craftsmanship × 0.75 + fortune × 0.35 + material and runestone bonuses.

- A **masterwork** (craftsmanship of 115% or more) adds 26.
- With the default thresholds (magic 68, rare 88, legendary 112), exceptional work becomes legendary even with a poor fortune roll. Sloppy work cannot reach legendary even with a perfect roll.
- All of these numbers live in `data/crafting.json`.

**Legendary discovery** is the same everywhere (crafting, loot bags, gifts):

- a distinct drop sound
- a star on the slot
- orange text
- a screen flash
- an ember burst

## Containers and progressive reveal

- Container types: traveller's bags, miner's shipments, relic satchels, gift purses, recovered chests and reward packages.
- Opening one reveals its contents one at a time. Each slot shows "?" while a short search runs; rarer finds take a beat longer and get stronger presentation.
- Contents and rarity are fixed by the loot tables when the container is created; the reveal only presents them.

## Hirelings

- Up to 3 hirelings (4 with Brannoc). You start with **Borin Flintbeard**, a dwarf miner and procurer.
- **Work skills:** Mining, Alchemy, Runecraft, Smithing, Travelling, Relic Hunting. Each is trainable through work and expeditions.
- **Work time:** allocated in percent per skill, and must total 100%.
- **Hourly output:** ore, herbs and reagents, raw runestones, ingots or nails, small trade income, or the occasional relic.
- **Wages** are paid daily.
- **Expeditions** go to Ironroot Mine, Whisperwood, Highmarsh Road, Barrow Fields and Deep Ironroot (which needs the Delve Map).
  - The outcome depends on skill, gear, danger and chance: success, a partial haul, injury or permanent death.
  - Hirelings visibly leave and return through the village exits.
  - Borin's first bag always holds a legendary and some mithril.
- **Recruitment:** the notice board offers 3–4 random applicants each week. They differ in race, personality and skill spread, and you can hire, replace or dismiss them.

## Autonomous adventurers

There are eight named adventurers:

| Name | Class |
|---|---|
| Mira | Ranger |
| Sigrun | Fighter |
| Elowen | Wizard |
| Kestra | Rogue |
| Garrick | Paladin |
| Tomas | Cleric |
| Varn | Barbarian |
| Pip | Bard |

**Their lives:**

- Each has a class, level, gold, equipment slots and a personality.
- Some have family in the village: Mira's father is Aldric, Garrick's mother is Martha, and Kestra's brother is Tobin.
- They rest at the inn, visit the shop, leave at dawn through an exit, run a simulated expedition and return.
- Their power is their level plus their equipment score.
- Expeditions bring experience, gold and loot, and can bring wear, injury or death.

**What they buy and order:**

- They buy from your displayed stock only if an item is an upgrade they can afford at a fair price.
- They place commissions for their weakest slot, specifying the slot, a minimum statistic, a reward and a deadline.

**The overview [J]** shows approximate ratings, locations, gear, last reports and how each one regards you (in words, not numbers).

## Business

- Customers arrive during opening hours. Adventurers browse your stock; villagers bring repairs, which you do with a grinding-wheel check.
- Unserved customers give up and leave a little annoyed.
- **Commissions:** delivering above the requirement pays a bonus and can earn a **reward package**.
- **Ledger [L]:** revenue and expenditure by category, net per day, a journal, and upgrades (alchemy, runecraft, arcane foundry, display cases, apprentice hooks).

## Relationships and village memory

- Each NPC tracks familiarity, affection, memories and a romance stage. There are no visible meters.
- Effects spread to relatives at 60%, with kin memories ("what the smith did for my daughter").

**Working consequences:**

- Grateful NPCs leave **gift purses**.
- A resentful NPC can **egg your storefront** overnight; you clean it up.
- Excellent commissions can earn **rare reward packages**.
- **Gossip:** sour memories spread to Pip and Wenna.
- Family members warm to you when you help their relative, and turn bitter if your shoddy gear got them killed.

## Inn, romance and marriage

**Inn:**

- Talk to anyone for personal stories that unlock with familiarity, or buy a round for the room.
- **Velvet Lantern:** adult companions. Ask about rumours, which reveal details in the adventurer overview, or spend an evening (discreet fade-to-black).

**Romance (adult women adventurers: Mira, Sigrun, Elowen, Kestra):**

1. Share drinks in the evening.
2. After two good evenings you are dating.
3. At high affection, court her.
4. Propose with a silver band from your own anvil.

**Marriage:**

- She keeps adventuring.
- Gear you give her is free.
- She brings half her gold and spare loot home.
- She sleeps in your quarters when in town.
- Her death is permanent and weighs on the village.

## The grocer

Aldric delivers provisions on day 3 and then weekly. There is no hunger system; the delivery is atmosphere and relationship.

**Quality varies with how he feels about you:**

| His attitude | What he brings |
|---|---|
| Cold | Stale bread |
| Neutral | The standard basket |
| Warm | The good bread, ham and herbs |
| Fond | A gift purse |

**The Mira story chain:**

1. On day 1 he asks you to arm Mira before she leaves for the Barrow Fields on day 3. This creates a commission.
2. Equip her well and he brings an Ember Runestone a traveller paid him with.
3. Fail her, or let shoddy gear hurt her, and he cools.

## Objectives and saving

- The HUD guides the first-day loop through talking to Borin, crafting a sword, arming Mira, the inn, departures, Borin's bag and saving.
- **Saving:** three manual slots, an autosave when you sleep, and a quicksave. All world state is restored, including relationships, memories, expeditions, orders, containers and the clock.

## Simplified in this first build

- Balance is provisional: prices, XP curves, danger maths and drop rates.
- All stations share one precision-check mechanic. They differ in their operations, difficulty, sound and visual feedback, but there are no station-specific minigames yet.
- Hirelings use the same skill framework, but they do not yet craft at stations themselves.
- The shop counter is the main sales interface. Customers don't physically take items from the shelves.
- Expedition combat is a statistical simulation; there is no tactical combat.
- Romance is a small working example; there is no marriage ceremony scene beyond a fade.
- Villagers use simple hourly schedules, and NPCs don't collide with each other.
- Hireling equipment exists in the model (Borin carries an axe and jerkin) but has no management screen yet.
- All art and audio are procedurally generated first-pass assets.

## Iteration 1 screenshots

`docs/screenshots/iteration1/` holds 32 screenshots, all captured by the rendered play-test (`tests/playtest.tscn`, phases `interiors`, `craft` and `craft_reload`). They show:

- **Workshop:** the plan, the discipline rooms, the locked-but-inspectable Arcane Foundry and the shopfront
- **Private quarters:** living room, study and bedroom
- **Other interiors:** the inn's common room, the Velvet Lantern upstairs, the grocer and a home
- **Crafting flow:**
  - station recipes
  - precision checks at the forge, anvil, quench, rune stand and cauldron
  - digital and physical dice
  - results for the iron sword, steel sword, armour, runestone, alchemy, leather and a legendary
- **Persistence:** the same legendary reopened from the stores after a restart
