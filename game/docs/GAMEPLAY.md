# Ember & Ash — gameplay systems in the first build

> **Build status:** all systems are implemented in code and data. This build has **not yet been run inside the Godot engine**, because the build environment could not download or execute a Godot binary. The checks so far are:
>
> - static: GDScript syntax checks, a Godot 4.3 API/type review, and data cross-checks
> - the baseline test scene (`tests/test_runner.tscn`), which is ready to run
>
> Expect a short round of engine-side fixes on first launch. See the final report for details.

## The village of Brindlewick

The village is about 96 × 64 tiles of 64 px each. It is built from modular sprites:

- textured ground, roads and a cobbled square, plus a stream with a bridge
- 9 buildings, each with walls, doorways, a furnished interior and a roof that fades when you enter
- 4 exits: Whisperwood (W), Highmarsh Road (E), Ironroot Mine (N) and Barrow Fields (S)

| Place | What you can do |
|---|---|
| **Ironhand Forge** | The workshop: 25 specialist stations plus the anvil, in five working bays. Shop counter and display. Living quarters with your bed. Bags from expeditions land on the floor here. |
| **The Tipsy Wyvern** | The inn, right across the road from the forge. Bar, hearth, tables, adventurers and Hilde. Stairs lead up to the guest rooms and the **Velvet Lantern**, where adult companions offer conversation, rumours and a discreet fade-to-black evening. |
| **Pell's Provisions** | Aldric the grocer's shop. |
| **Village square** | Notice board (applicants, commissions, news), well and market stall. |
| **Other buildings** | Martha's cottage, Tobin's workshop, the Chapel of the Dawn, Jory's farm, Eda's and Cooper's Row houses. |

**Day and night:**

- The clock runs about 15 real minutes per day; Settings can change this.
- The light shifts through dawn, day, dusk and night.
- Lanterns, doors and windows light up at night; hearths and forges flicker.
- The music and ambience follow where you are and the time of day.

## Crafting: the 25 stations

Each station has its own sprite, interface panel, purpose text, unlock rule and check parameters (count, speed, zone width, weight). All parameters are data-driven in `data/stations.json`.

| Discipline | Stations | Unlock |
|---|---|---|
| Classic Smithing | Forge, Crucible, Quenching Trough, Bellows, Grinding Wheel (+ Anvil) | Available from the start |
| Runecrafting | Cutting Bench, Engraving Stand, Cleansing Basin, Resonance Pedestal, Polishing Wheel | Runewright's Tools upgrade |
| Alchemy | Mortar & Pestle, Alembic, Cauldron, Reagent Table, Infusion Rack | Alchemist's Kit upgrade |
| Arcane Metalworking | Arcane Crucible, Spellbinding Array, Leyline Conductor, Aetheric Stabilizer, Imprinting Anvil | Arcane Foundry: Runecraft 3, mithril found, 600 g |
| Enchanted Stitching | Stitching Table and Leather Vat (basic leather); Thread Spinner, Embroidery Frame and Fitting Mannequin (enchanted) | Basic from the start; Enchanted Stitching 3 for the enchanted stations |

**How a recipe works:**

1. Choose a recipe at any station it uses. The ingredients are consumed.
2. Visit the stations in order. Each step runs the **circular skill check**.
3. Roll the dice.
4. The item is revealed.

There are 23 demonstration recipes across all five disciplines, including:

- ingots and steel
- sword, axe, mace, cuirass, helm and shield
- a silver band (the proposal ring)
- leather goods and warded gloves
- oils, potions and coatings
- runestones
- charged mithril and the **Mithril Runeblade**, whose arcane markings are part of the metal itself

**Socketing:** at the Rune Engraving Stand you can set finished runestones into existing equipment. This is distinct from arcane metal.

## Skill check

- A needle sweeps the ring. You stop it with E, Space or a click.
- The score depends on how close to the zone's centre you stop it:
  - perfect centre: 114–120%
  - zone edge: about 70%
  - misses fall towards 10%
- Several checks per station feed a weighted mean. A poor check lowers quality; it never destroys the item.
- Skill widens the zone and slows the needle.
- Every check has visual and audio feedback.

## Dice

- **Digital:** animated rolls.
- **Physical:** you roll real dice and enter the faces; values are validated.
- Typical dice:
  - Weapons: edge d20, temper d12, fortune d100
  - Armour: guard d20, temper d12, fortune d100
  - Materials: purity d6
- Craftsmanship dominates the stats; the main die shifts them ±15%.
- Rarity comes from quality × 0.65 + fortune × 0.45 (+ runestone/arcane bonuses). Excellent work survives a bad roll; perfect work plus a great roll gives a legendary.

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
- All 25 stations share one universal check. Station-specific minigames are planned.
- The shop counter is the main sales interface. Customers don't physically take items from the shelves.
- Expedition combat is a statistical simulation; there is no tactical combat.
- Romance is a small working example; there is no marriage ceremony scene beyond a fade.
- Villagers use simple hourly schedules, and NPCs don't collide with each other.
- Hireling equipment exists in the model (Borin carries an axe and jerkin) but has no management screen yet.
- All art and audio are procedurally generated first-pass assets.
