# Ember & Ash — gameplay systems

> **Vertical-slice candidate (iterations 003–008):** see [PLAYGUIDE.md](PLAYGUIDE.md) for how to play the whole loop and [VERTICAL_SLICE_REPORT.md](VERTICAL_SLICE_REPORT.md) for what works, what is shallow and what is deferred. The sections below describe the systems in detail. Iteration 003–008 additions are summarised at the end.

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
| **Shopfront** | Counter, displays and the street entrance. |
| **Waiting area** (outside the street door) | Four seats under a striped sign, plus a decorative stand showing the kinds of equipment the forge makes. At most four customers wait at once. You are told about a customer only when they actually sit down. Talk to a waiting customer to serve them, take a repair job, or ask them to come back another time, which frees their seat. Customers who wait too long give up. |
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

## Skill checks: the precision ring and five specialised minigames

Every station runs a skill check for each operation. Each check, or round, gives a continuous craftsmanship value that can exceed 100%. Skill eases every check: a wider target and slower movement. You still have to play it. Every check gives a grade, a sound and an effect at the station: sparks, steam, bubbles, rune light or arcane flashes. All checks accept the mouse and the keyboard.

| Check | Where | How it plays |
|---|---|---|
| **Precision ring** (default) | Forge, anvil, crucible, quench, cutting bench, cleansing basin, stitching, vat, mannequin, arcane stations | Stop the sweeping needle in the ember zone (E, Space or click). The centre gives 120%, the edge 70%, and misses fall towards 10%. |
| **Spark & Ember Alignment** | Bellows | Two rotating mechanisms are pushed about by the airflow. Turn the Spark wheel (A/D or ←/→) and the Ember ring (W/S or ↑/↓), or drag either with the mouse. Pump (E, Space, or click the hearth) when both notches face the vent. The flame, sparks and airflow show how close you are, and each mechanism clicks as it enters the window. Quality depends on how precisely both are aligned at the pump. |
| **Edge Control** | Grinding wheel, rune polishing wheel | A close-up of the blade on the stone. Hold the angle (W/S or mouse up/down) and the pressure (A/D or mouse left/right) on a sweet spot that slowly wanders, while the grit kicks the blade now and then. Quality is the precision you hold over the whole pass. The sparks and the ghost of the ideal blade show how you are doing. |
| **Multi-Hit Sequence** | Embroidery frame, resonance pedestal, thread spinner, spellbinding array, infusion rack | After a brief pause, one fast sweep crosses four or five glowing sections. Press as the needle crosses each one. Every hit counts the same, wherever in the section it lands. Quality depends on how many sections you strike; a press outside a section costs a little. Striking all five is exceptional. |
| **Rune Stabilization** | Rune engraving stand, including setting runestones into equipment | A charged rune hovers above the engraved socket on the blade. It has momentum, the socket's magic swirls it sideways, and it surges. Guide it in with the mouse (it follows, lagging) or push it with W/A/S/D, then hold it seated for the binding. Quality is how closely and steadily it stays. |
| **Ring Contact** | Mortar and cauldron (inward); alembic and reagent table (outward) | A still ring appears, then a second ring contracts or expands towards it. Press when they meet. Effects suit mixing, brewing, distilling and volatile reactions. |

- Which check a station uses is set in `data/crafting.json` (`minigames`).
- Each operation's rounds are averaged. Operations are weighted, so drawing out the blade matters more than wrapping the grip.
- The final craftsmanship feeds dice, stats and rarity exactly as before.

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

You can employ up to 3 hirelings alongside Brannoc. You start with **Borin Flintbeard**, a dwarf miner: *Stout-hearted* (+30% mining) but *Clumsy with glassware* (−40% alchemy).

**Skills:**

- Everyone, Brannoc included, shares the same trainable skills: Mining, Smithing, Alchemy, Runecraft, Travelling (scouting, trading, transport) and Relic Hunting.
- Skills rise with the work that uses them.
- **Traits:** each employee has a strength and often a weakness, such as Forge-born, Nimble fingers, Silver tongue, Keen eye, Quick learner or Hardy, against Bad back, Fearful, Frail, Restless or Heavy-handed. Traits change their output, their expedition risk and how fast they learn.
- Nobody is locked to a profession. Anyone can do any work; skill and traits decide how well.

**Work in the Ledger of Hands [H]:**

- Split working time (8:00–18:00) between the six skills; the split must total 100%.
- One-click presets: focus on the best skill, split the two best, or an even spread.
- Each hour employees work autonomously, gain experience and produce results: ore, ingots, herbs, runestone blanks, trade income or relics.
- The ledger shows each employee's current activity with progress to the next result, their levels and experience bars, a short work log and their expedition history.
- Wages are paid daily.

**Gear:** give weapons and armour from your stores to an employee. Gear raises their expedition power.

**Expeditions:**

| Destination | Notes |
|---|---|
| Ironroot Mine | Mining |
| Whisperwood | Scouting |
| Highmarsh Road | Trade |
| Barrow Fields | Relics |
| Deep Ironroot | Mining; needs the Delve Map |

- Destinations differ in danger, duration (1–4 days) and loot.
- Before you send someone, the ledger shows the risk (safe, risky, dangerous or deadly), the chance of success and of injury, and whether they could die. These come from their skill, travelling, gear and traits.
- Possible outcomes: a full haul, a partial haul, injury (days of rest) or permanent death.
- Every trip gives experience.
- While someone is away their workshop schedule pauses. They visibly leave and return through the village exits.
- Bags wait on the workshop floor.
- Borin's first bag always holds a legendary and some mithril.
- Expedition state, injuries, deaths and histories are saved.

**Recruitment:**

- The village notice board pins a new set of applicants each week. Some weeks nobody answers; most weeks two to four people do, each with their own race, personality, skill spread and traits.
- You cannot always get the ideal candidate.
- When all three places are taken, you can replace an employee who is at home with an applicant in one step.

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

### The living village (expeditions on the clock)

Since the Living Village update the adventurers' expeditions are no longer a single dice roll at the end of a day. Each adventurer is persistent: health and maximum health, injuries and recovery, fatigue, morale, five attributes (STR, DEX, INT, WIS, CON), class skills (guard, heal, firebolt, smite, rage, sneak attack, inspire, scouting, archery …), preferred weapon types, gear, gold, a trait, a risk tolerance, relationships with each other (friends and rivals), renown with titles (Unknown → Local Name → Rising Blade → Hero of Brindlewick → Living Legend), achievements and a history.

- **Parties** form at the inn at 06:00 (one to four members, chosen by friendship, role balance and risk), provision at 07:00 and depart at 08:00. They choose a region by their strength and appetite for risk, avoid repeating the last trip and, if someone is missing, may go searching.
- **Regions** (`data/expeditions.json`, generated by `tools/data/make_expeditions.py`): Whisperwood, Ironroot Mine, Highmarsh Road, the Barrow Fields and Deep Ironroot. Each has a node map of entry, paths, encounters, traps, chests, resources, shrines, rune doors, travellers and a boss, and 15 enemy types with hit points, attack, damage, armour class, weaknesses and resistances.
- **Time:** travel and every action take game minutes. The expedition advances on the game clock (every five game minutes) regardless of frame rate or whether anyone watches.
- **Checks** use d20 + attribute (+2 for a matching skill) against a difficulty class. **Combat** rolls d20 + to-hit against defence (10 + DEX + protection × 0.25); damage comes from the weapon's attack stat × 0.55 + the main attribute, with fire/frost/magic doubled against a weakness, physical damage reduced by a resistance, and armour absorbing part of each blow. Weapons and armour lose durability and can **break** (a broken weapon halves its attack and is brought in for repair). Healing draughts are drunk at low health; the party retreats when it is losing or exhausted.
- **Outcomes:** returned, retreated, missing (everyone down; a hidden death save decides whether they live) or rescued (Apprentice). Death depends on difficulty.
- **Event chains:** *Missing Party* (search parties, return or revealed fate, recovered weapons), *Broken Blade* (repair job and a new order), *Relic Hunter* (a relic sold to the forge earns a special commission) and *Unexpected Hero* (a weak member lands the killing blow on a boss).
- **The chronicle** is a single log of everything notable. The board, dossiers, dialogue and the journal all read from it.

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

## Simplified so far

- Balance is provisional: prices, XP curves, danger maths and drop rates.
- Five families of stations have specialised minigames; the rest keep the precision ring. Minigame difficulty curves are provisional.
- Hirelings use the same skill framework and work autonomously, but they produce from their allocation rather than crafting recipes at stations.
- The shop counter is the main sales interface. Customers don't physically take items from the shelves.
- Expedition combat is a statistical simulation; there is no tactical combat.
- Romance is a small working example; there is no marriage ceremony scene beyond a fade.
- Villagers use simple hourly schedules, and NPCs don't collide with each other.
- Hireling gear is handed over from the stores in the ledger; there is no separate equipment screen per slot.
- Animals wander a fixed home range in straight lines; they do not use the navigation graph.
- All art and audio are procedurally generated first-pass assets.

## Characters and village life

- **Figures:** characters are painted tabletop miniatures on small decorative bases, in the ink-and-parchment style. Each has front, side and back poses, and never rotates the whole figure. Walking is a restrained step and hop on a planted base.
- **Animals:** two cats and two dogs live around the square, the inn and the forge. They sit, look about and trot short distances.
- **Atmosphere:**
  - Flowers, bushes and tree crowns sway in a light breeze.
  - Fine dust drifts over the streets and through the workshop and inn.
  - The forge corner is darker and sootier, with a strong warm hearth glow, rising smoke and embers.

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

## Iteration 2 screenshots

`docs/screenshots/iteration2/` holds 25 screenshots captured by the rendered play-test (phases `minigames`, `iter2`, `iter2_reload` and `craft`). They show:

- each of the five specialised minigames, and the same minigames inside real crafts
- the hirelings ledger before and after expeditions, and after a reload
- the notice board, including replacing an employee when all places are taken
- the four-seat waiting area, asking a customer to leave, and the freed seat
- the crafting display
- tabletop figures, cats and dogs, flowers in the breeze, and the darker forge corner


## Iterations 003–008 in brief

### 003 — Materials, relics and discovery

**Gems and rare minerals:** garnet, sapphire, moonstone, starstone, starmetal and adamantine. What you find depends on the region and on the finder's skill.

**Regions:** scouting knowledge lowers danger for everyone, and new suppliers are found along the way.

**Trade runs:** a hireling carries a purse to buy materials and sells the goods you marked for trade.

**Relics:** unidentified relics are studied by you, or by a relic hunter during work hours. They turn out to be ancient arms, components or forgotten recipes.

**Processing:** skilled hirelings turn stored herbs into draughts and oils, and runestone blanks into prepared runestones.

### 004 — The adventurers' world

**Encounters:** expeditions are fought one encounter at a time. Each threat has weaknesses and resistances.

- What decides a fight: attack, fire, frost, magic, protection, ward, carried draughts and coatings.
- Logs credit the gear that mattered.

**Adventurers:** each has a trait, a planned next trip, and orders that follow that trip's threats. They buy draughts before leaving.

**Overview:** what you see depends on how well you know them.

### 005 — The village remembers

**Commerce:**
- Reputation sets how busy the shop is and what prices people accept.
- Customers bring budgets and wants, and villagers buy goods.
- Upkeep is charged daily, and stock is laid out on the display table.

**Consequences:**
- Disputes can be refunded or refused.
- Hostile people refuse to trade.
- Friends share road knowledge, and devoted friends bring relics.

### 006 — A life beyond the anvil

**The inn:** table talk drawn from real events, and knucklebones.

**Romance:** personal beats lead to marriage: a walk by the stream, a keepsake, and a wedding of her own.

**Married life:** her family warms to you, she greets you in her own words, gear is free for her, and spoils are shared.

### 007 — Masters of the forge

**New crafts:**
- Jewellery with gems.
- Frost coating, and treating equipment with oils and coatings.
- Ranger's boots and an embroidered hood.

**Arcane metalworking:** the adamantine chain, with magic **bound into the metal**.

**Special blades:**
- The four-discipline Emberwarden.
- The forgotten Starsteel recipe.

**Workshop help:** hirelings assist at the bench, and adventurers bring their own gear for repair.

### 008 — Integration

**Developer Tools (F10):** for testing only, separate from normal play.

**Verification:**
- A 28-day soak test of the living world.
- The end-to-end rendered session and reload, `slice` and `slice_reload`.

## Living Village screenshots

`docs/screenshots/living_village/` (from the `village` play-test phase):

| File | Shows |
|---|---|
| `difficulty_choice.jpg` | Apprentice / Journeyman / Master at New Game |
| `board_wanted.jpg` | The MOST WANTED board: pinned sheets ranked by renown |
| `board_active.jpg` | Active expeditions with Observe buttons |
| `dossier_buyer.jpg` | A dossier carrying the exact sword the smith sold, with maker mark |
| `observe_live.jpg` | Live observation: region map, party marker, members, journal |
| `revisit_fight.jpg` | Replay of a past fight with every roll and damage breakdown |
| `board_legends.jpg` | Hall of renown, chronicle and past expeditions |
| `shop_offers.jpg` | Finds offered at the shop counter |
| `master_board.jpg` | Master difficulty: departure times and rumours only |


## Iteration 009 — The Living Village, Ironfront, workshop expansion, natural progression

| System | What it does | Code / data |
|---|---|---|
| **Workshop ownership** | The smith owns a corner of a 30×23-tile building; six neighbouring units can be bought only when they adjoin his rooms. Unowned rooms keep their occupants' furnishings behind locked doors | `property.gd`, `make_layout.py` (`SMITHY_UNITS`, tagged furniture) |
| **Workshop editing** | On a drawn plan: put up or take down internal walls (rooms stay rectangles), cut or brick up doorways, change a room's use, buy/place/move/turn stations. A half-tile walk grid checks that every owned room, station, the counter and a bed stay reachable from the front door. Stations stand only in workshop rooms (capacity one per 12 tiles²). The world is rebuilt from the plan | `property.gd`, `property_panel.gd`, `world.gd` (`_smithy_view`) |
| **Skill tree** | 45 nodes in six branches gate every recipe and station. Requirements: skill level, prior nodes, knowledge flags, installed stations, materials held, tuition. Techniques add small quality bonuses; secrets stay hidden | `skilltree.gd`, `make_skilltree.py` |
| **Progressive content** | 17 new recipes (steel cuirass, bear and wyrm leather, orichalcum, original and combination runes, mithril-plated cuirass, Dragonscale Armour …) and 11 exotic materials with real sources | `make_recipes.py`, `extra_progression.py`, `extra_trade.py` |
| **Equipment designer** | Plan an item from known type, material, rune and treatment; shows stats and missing requirements; starts the craft and applies rune and treatment afterwards | `designer_panel.gd` |
| **Skill checks** | First-time how-to cards with practice at tutorial difficulty, auto-closing results, explicit difficulty factors (skill, recipe complexity, station tier, fatigue), an assist setting, gentler Infusion Rack and wheels, a much slower Resonance Pedestal | `crafting.gd` (`check_params`), `scripts/ui/minigames/` |
| **Customers** | Request cards (item, attribute, material, budget, reward); notices only once seated outside; dismissal at the counter | `shop.gd`, `customer_card.gd` |
| **Fatigue & appearance** | Energy falls with crafting and waking hours and narrows checks; rest by the hearth, sleep in bed. The smith's looks are customisable (layers recoloured in-engine; default unchanged) | `vitality.gd`, `appearance.gd`, `customize_panel.gd` |
| **Trade** | Herbalist with daily stock; merchant ships every 3–6 days (spice, ore barge, whaler); special imports with deposits and lead times | `trade.gd`, `make_trade.py` |
| **Village** | Denser village with woodland boundaries, groves, pond, harbour and estuary, herbalist, Barnaby's house and basement, cooperage, stable, chandler, net loft; grit and clutter; a real day/night curve with lit windows and street lamps; venue ambience | `village_layout.py`, `world.gd` |
| **Ironfront** | 55-card WWII-as-fantasy card game: three fronts, best of three, commanders, tactics, Blitzkrieg mode, four AI opponents, deck builder, collection, Barnaby's shop, rewards, tutorial | `ironfront.gd`, `ironfront_*.gd`, `make_ironfront.py` |
| **Róisín** | Romanceable Velvet Lantern worker (red hair, green eyes): stages to marriage, buying out her contract, discreet fades | `roisin.gd`, `extra_village.py` |
| **Interface** | Illustrated bottom toolbar, minimap with talk markers, map panel, ledger tabs, contextual histories for people/items/stations, guided tutorial, searchable non-spoiling reference | `hud_toolbar.gd`, `village_map_view.gd`, `history.gd`, `tutorial.gd`, `reference.gd` |
| **Audio** | `assets/audio/inbox/` drop-in folder (override → inbox → shipped); Ironfront march, harbour and pond loops | `audio.gd` |

**Screenshots:** `docs/screenshots/iteration_009/`.
