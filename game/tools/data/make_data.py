"""Generates game/data/*.json (single source for code, art and audio pipelines).
Run: python3 tools/data/make_data.py"""
import json, os
D = os.path.join(os.path.dirname(__file__), "..", "..", "data")

def W(name, obj):
    with open(os.path.join(D, name), "w") as f:
        json.dump(obj, f, indent=1, ensure_ascii=False)

# ---------------------------------------------------------------- stations
# pos = centre in tiles relative to the smithy rect; size = sprite px (art must match)
def st(id, name, disc, pos, size, purpose, check, unlock=None, sfx="hammer", fx=None, solid=True):
    return dict(id=id, name=name, discipline=disc, pos=pos, size=size, purpose=purpose,
                check=check, unlock=unlock or {}, sfx=sfx, fx=fx or [], solid=solid)
C = lambda n, spd, zone, w=1.0: dict(count=n, speed=spd, zone=zone, weight=w)
stations = [
 st("anvil", "The Anvil", "classic", [12, 10], [112, 80], "Shapes heated metal into blades, plates and fittings. The heart of ordinary smithing.", C(3, 0.55, 34, 1.4), sfx="hammer"),
 st("forge", "Forge / Hearth", "classic", [2.6, 9], [160, 128], "Heats metal to working temperature. Colour of the glow tells the smith when to strike.", C(1, 0.45, 40), sfx="bellows", fx=["fire", "light_forge", "embers"]),
 st("crucible", "Crucible", "classic", [2.4, 12.8], [96, 96], "Melts ore and combines metals into ingots and alloys.", C(2, 0.5, 36), sfx="bubble", fx=["glow_small"]),
 st("quench_trough", "Quenching Trough", "classic", [6.6, 12.6], [128, 64], "Cools and hardens finished work. Too slow and the steel stays soft; too fast and it cracks.", C(1, 0.65, 30), sfx="quench", fx=["steam"]),
 st("bellows", "Bellows", "classic", [5.0, 8.4], [96, 96], "Feeds air to the forge to raise the heat for steel and alloys.", C(2, 0.6, 38, 0.7), sfx="bellows"),
 st("grinding_wheel", "Grinding Wheel", "classic", [7.0, 5.2], [96, 96], "Sharpens edges and finishes surfaces. Also used for repairs.", C(1, 0.7, 30), sfx="grind", fx=["sparks"]),
 st("rune_cutting_bench", "Runestone Cutting Bench", "runecraft", [2.6, 16.6], [128, 80], "Cuts raw runestone into workable blanks.", C(1, 0.5, 34), sfx="chisel"),
 st("rune_engraving_stand", "Rune Engraving Stand", "runecraft", [5.4, 16.8], [96, 96], "Engraves runes into blanks and sets finished runestones into equipment.", C(2, 0.6, 28), sfx="chisel", fx=["rune_glow"]),
 st("rune_cleansing_basin", "Runic Cleansing Basin", "runecraft", [7.6, 16.8], [96, 96], "Washes residual chaos from freshly engraved stones.", C(1, 0.45, 40), sfx="water", fx=["rune_glow"]),
 st("resonance_pedestal", "Resonance Pedestal", "runecraft", [9.8, 16.8], [96, 96], "Tunes a runestone until its hum steadies.", C(2, 0.7, 26), sfx="rune_hum", fx=["rune_glow", "light_rune"]),
 st("rune_polishing_wheel", "Runestone Polishing Wheel", "runecraft", [12.0, 16.8], [96, 96], "Polishes runestones to a mirror finish, raising their potency.", C(1, 0.6, 32), sfx="grind"),
 st("mortar_station", "Mortar & Pestle Station", "alchemy", [15.0, 17.0], [96, 80], "Grinds herbs, salts and minerals into reagents.", C(2, 0.5, 36), sfx="grind_soft"),
 st("alembic", "Alembic", "alchemy", [17.3, 16.9], [112, 96], "Distils oils and essences.", C(1, 0.55, 32), sfx="bubble", fx=["glow_small"]),
 st("cauldron", "Alchemical Cauldron", "alchemy", [19.7, 16.6], [112, 112], "Brews potions, coatings and tempering baths.", C(2, 0.5, 34), sfx="bubble", fx=["bubbles", "light_green"]),
 st("reagent_table", "Reagent Separation Table", "alchemy", [22.2, 17.1], [128, 80], "Separates mixtures into pure reagents.", C(1, 0.65, 28), sfx="glass"),
 st("infusion_rack", "Infusion Rack", "alchemy", [16.0, 13.4], [128, 64], "Steeps infusions and finishes potions.", C(1, 0.45, 40), sfx="glass"),
 st("arcane_crucible", "Arcane Crucible", "arcane", [26.4, 12.4], [128, 128], "Melts mithril and adamantine while binding magic into the molten metal itself.", C(2, 0.75, 24, 1.3), unlock={"upgrade": "arcane_foundry"}, sfx="arcane", fx=["arcane_glow", "light_arcane"]),
 st("spellbinding_array", "Spellbinding Array", "arcane", [25.6, 16.2], [160, 160], "A floor circle that locks a spell pattern into cooling metal.", C(2, 0.8, 22), unlock={"upgrade": "arcane_foundry"}, sfx="arcane", fx=["arcane_glow"], solid=False),
 st("leyline_conductor", "Leyline Conductor", "arcane", [28.6, 12.6], [96, 128], "Draws power from the leyline beneath Brindlewick.", C(1, 0.7, 26), unlock={"upgrade": "arcane_foundry"}, sfx="arcane", fx=["arcane_glow", "light_arcane"]),
 st("aetheric_stabilizer", "Aetheric Stabilizer", "arcane", [28.4, 16.6], [112, 112], "Keeps charged alloys from tearing themselves apart.", C(1, 0.6, 30), unlock={"upgrade": "arcane_foundry"}, sfx="arcane", fx=["arcane_glow"]),
 st("arcane_anvil", "Arcane Imprinting Anvil", "arcane", [22.8, 12.6], [128, 96], "Hammers the bound magic into visible, glowing patterns in the finished piece.", C(3, 0.7, 24, 1.4), unlock={"upgrade": "arcane_foundry"}, sfx="hammer_arcane", fx=["arcane_glow"]),
 st("stitching_table", "Enchanted Stitching Table", "stitching", [18.0, 6.8], [128, 80], "Cuts and stitches leather goods: jerkins, boots, gloves, belts and bracers.", C(2, 0.5, 36), sfx="stitch"),
 st("thread_spinner", "Ethereal Thread Spinner", "stitching", [20.6, 6.8], [112, 96], "Spins moonlit thread that holds enchantments.", C(1, 0.6, 28), unlock={"skill": ["enchanted_stitching", 3]}, sfx="spin", fx=["thread_glow"]),
 st("leather_vat", "Leather Treatment Vat", "stitching", [22.6, 7.2], [112, 112], "Cures raw hides into supple, durable leather.", C(1, 0.45, 40), sfx="water"),
 st("embroidery_frame", "Arcane Embroidery Frame", "stitching", [18.2, 9.8], [112, 112], "Embroiders protective sigils into textiles and leather.", C(2, 0.7, 26), unlock={"skill": ["enchanted_stitching", 3]}, sfx="stitch", fx=["thread_glow"]),
 st("fitting_mannequin", "Enchanted Fitting Mannequin", "stitching", [20.8, 9.9], [80, 96], "Fits and balances finished garments so enchantments sit true.", C(1, 0.55, 32), unlock={"skill": ["enchanted_stitching", 3]}, sfx="stitch"),
]
W("stations.json", stations)

# ---------------------------------------------------------------- items
def it(id, name, type, slot=None, value=10, stats=None, icon=None, stack=False, desc="", tags=None):
    return dict(id=id, name=name, type=type, slot=slot, value=value, stats=stats or {}, icon=icon or id,
                stack=stack, desc=desc, tags=tags or [])
items = [
 it("sword_iron", "Iron Longsword", "weapon", "weapon", 60, {"attack": [8, 12], "durability": 60}, desc="A plain, honest blade."),
 it("sword_steel", "Steel Longsword", "weapon", "weapon", 140, {"attack": [12, 17], "durability": 90}),
 it("sword_mithril", "Mithril Runeblade", "weapon", "weapon", 520, {"attack": [18, 26], "durability": 140, "magic": 10}, tags=["arcane"]),
 it("sword_bastard", "Steel Bastard Sword", "weapon", "weapon", 260, {"attack": [16, 22], "durability": 120}, icon="sword_steel", desc="A hand-and-a-half blade. A master's work."),
 it("axe_hand", "Hand Axe", "weapon", "weapon", 55, {"attack": [9, 13], "durability": 55}),
 it("mace_flanged", "Flanged Mace", "weapon", "weapon", 90, {"attack": [10, 15], "durability": 85}),
 it("dagger", "Dagger", "weapon", "weapon", 35, {"attack": [5, 8], "durability": 40}),
 it("shield_round", "Round Shield", "shield", "shield", 45, {"protection": [4, 7], "durability": 70}),
 it("shield_kite", "Kite Shield", "shield", "shield", 95, {"protection": [6, 10], "durability": 90}),
 it("cuirass_iron", "Iron Cuirass", "armor_metal", "armor", 120, {"protection": [10, 15], "durability": 110}),
 it("chainmail", "Chain Hauberk", "armor_metal", "armor", 100, {"protection": [8, 12], "durability": 90}),
 it("jerkin_leather", "Leather Jerkin", "armor_leather", "armor", 50, {"protection": [5, 8], "durability": 60}),
 it("helm_iron", "Iron Helm", "helmet", "helmet", 45, {"protection": [3, 5], "durability": 70}),
 it("hood_leather", "Leather Hood", "helmet", "helmet", 20, {"protection": [1, 3], "durability": 40}),
 it("boots_leather", "Leather Boots", "boots", "boots", 25, {"protection": [1, 3], "durability": 50}),
 it("gloves_leather", "Leather Gloves", "gloves", "gloves", 20, {"protection": [1, 2], "durability": 40}),
 it("gloves_warded", "Warded Gloves", "gloves", "gloves", 160, {"protection": [3, 5], "durability": 60, "magic": 6}, tags=["enchanted"]),
 it("belt_leather", "Leather Belt", "belt", "belt", 15, {"protection": [0, 1], "durability": 50}),
 it("ring_silver", "Silver Band", "ring", "ring", 80, {"magic": 3}, desc="Plain silver. Fit for a promise."),
 it("amulet_silver", "Silver Amulet", "amulet", "amulet", 110, {"magic": 5}),
 it("runestone_blank", "Raw Runestone", "runestone", None, 25, stack=True),
 it("runestone_ember", "Ember Runestone", "runestone", None, 90, {"fire": 4}, stack=True, desc="Set into a weapon for burning strikes."),
 it("runestone_ward", "Ward Runestone", "runestone", None, 90, {"ward": 4}, stack=True, desc="Set into armour to turn aside harm."),
 it("runestone_frost", "Frost Runestone", "runestone", None, 110, {"frost": 4}, stack=True),
 it("ore_iron", "Iron Ore", "material", None, 4, stack=True),
 it("ore_copper", "Copper Ore", "material", None, 4, stack=True),
 it("ore_silver", "Silver Ore", "material", None, 15, stack=True),
 it("ore_mithril", "Mithril Ore", "material", None, 80, stack=True, tags=["rare"]),
 it("ore_adamantine", "Adamantine Ore", "material", None, 140, stack=True, tags=["rare"]),
 it("coal", "Coal", "material", None, 2, stack=True),
 it("ingot_iron", "Iron Ingot", "material", None, 10, stack=True),
 it("ingot_steel", "Steel Ingot", "material", None, 24, stack=True),
 it("ingot_mithril", "Charged Mithril Ingot", "material", None, 180, stack=True, tags=["arcane"]),
 it("leather_hide", "Raw Hide", "material", None, 5, stack=True),
 it("leather_cured", "Cured Leather", "material", None, 12, stack=True),
 it("thread_linen", "Linen Thread", "material", None, 3, stack=True),
 it("thread_ethereal", "Ethereal Thread", "material", None, 40, stack=True),
 it("herb_emberleaf", "Emberleaf", "material", None, 6, stack=True),
 it("herb_moonwort", "Moonwort", "material", None, 6, stack=True),
 it("reagent_salt", "Quicksalt", "material", None, 5, stack=True),
 it("oil_whetstone", "Whetstone Oil", "potion", None, 30, {"edge": 2}, stack=True, desc="Applied before a hunt; keeps edges keen."),
 it("potion_healing", "Healing Draught", "potion", None, 45, {"heal": 20}, stack=True),
 it("coating_flame", "Flame Coating", "potion", None, 70, {"fire": 2}, stack=True),
 it("relic_idol", "Barrow Idol", "relic", None, 120, desc="A squat stone figure, warm to the touch."),
 it("relic_coin", "Drowned King's Coin", "relic", None, 90),
 it("relic_map", "Faded Delve Map", "relic", None, 150, desc="Marks a passage beneath Ironroot no one remembers."),
 it("relic_crown_shard", "Crown Shard", "relic", None, 300, tags=["rare"]),
 it("ale_mug", "Tankard of Ale", "potion", None, 2, stack=True),
 it("bread_cheese", "Bread & Cheese", "material", None, 1, stack=True, desc="Grocer's weekly provisions."),
 # containers
 it("bag_traveller", "Traveller's Bag", "container", None, 0),
 it("shipment_miner", "Miner's Shipment", "container", None, 0),
 it("satchel_relic", "Relic Hunter's Satchel", "container", None, 0),
 it("purse_gift", "Gift Purse", "container", None, 0),
 it("chest_recovered", "Recovered Chest", "container", None, 0),
 it("package_reward", "Reward Package", "container", None, 0),
 # ---- iteration 3: gemstones, rare minerals, components and relics that need study
 it("gem_garnet", "Garnet", "material", None, 35, {"fire": 3}, stack=True, desc="A deep red stone. Smiths say it holds a little of the forge's heat.", tags=["gem"]),
 it("gem_sapphire", "Sapphire", "material", None, 45, {"frost": 3}, stack=True, desc="Cold blue, clear as a winter sky.", tags=["gem"]),
 it("gem_moonstone", "Moonstone", "material", None, 40, {"magic": 3}, stack=True, desc="Milky and pale; it seems to drink in lamplight.", tags=["gem"]),
 it("gem_starstone", "Starstone", "material", None, 160, {"magic": 5}, stack=True, desc="A rare dark mineral flecked with silver. Found only in the deep places.", tags=["gem", "rare"]),
 it("ingot_adamantine", "Charged Adamantine Ingot", "material", None, 260, stack=True, desc="Near-unbreakable metal with a ward bound into its grain.", tags=["arcane"]),
 it("starmetal_fragment", "Starmetal Fragment", "material", None, 120, stack=True, desc="A shard of something that fell from the sky long ago.", tags=["rare"]),
 it("relic_unknown_arms", "Corroded Ancient Arms", "relic", None, 40, desc="Crusted with centuries of grave-earth. Study it to learn what it was.", tags=["unidentified"]),
 it("relic_unknown_tablet", "Weathered Rune Tablet", "relic", None, 40, desc="Carved marks too worn to read at a glance.", tags=["unidentified"]),
 it("relic_unknown_reliquary", "Sealed Reliquary", "relic", None, 60, desc="Bronze gone green. Something rattles inside.", tags=["unidentified"]),
 it("recipe_scroll", "Forgotten Recipe", "relic", None, 80, desc="A smith's working notes from another age. Read it to learn the recipe.", tags=["recipe"]),
 it("coating_frost", "Frost Coating", "potion", None, 70, {"frost": 2}, stack=True, desc="Brushed onto a blade: rime spreads along the edge on the strike."),
 it("ring_garnet", "Garnet Ring", "ring", "ring", 160, {"fire": 4, "magic": 2}, desc="Warm to the touch."),
 it("amulet_sapphire", "Sapphire Amulet", "amulet", "amulet", 190, {"frost": 3, "ward": 3, "magic": 3}),
 it("sword_emberwarden", "Emberwarden Longsword", "weapon", "weapon", 420, {"attack": [14, 19], "durability": 110, "fire": 5}, desc="Steel, an ember rune in the guard, a flame-quenched edge and a ghost-thread grip.", tags=["enchanted"]),
 it("sword_starsteel", "Starsteel Blade", "weapon", "weapon", 480, {"attack": [17, 23], "durability": 160}, desc="Forged to a recipe older than the village."),
 it("warplate_adamantine", "Adamantine Warplate", "armor_metal", "armor", 700, {"protection": [16, 22], "durability": 190, "ward": 6, "magic": 4}, desc="Ward-magic bound into the metal itself; violet seams glow under strain.", tags=["arcane"]),
 it("boots_ranger", "Ranger's Soft Boots", "boots", "boots", 70, {"protection": [1, 3], "durability": 60, "speed": 6}, desc="Silent on leaf-litter. Light enough to run in."),
 it("hood_embroidered", "Embroidered Hood", "helmet", "helmet", 140, {"protection": [2, 3], "durability": 50, "ward": 4}, desc="Gold sigils stitched with ethereal thread turn aside curses.", tags=["enchanted"]),
 # named unique / set
 it("grimhold", "Grimhold, the Last Hammer", "weapon", "weapon", 900, {"attack": [24, 34], "durability": 200, "smithing": 2}, tags=["unique"]),
 it("wyvernscale_pauldron", "Wyvernscale Pauldron", "armor_metal", "armor", 400, {"protection": [14, 20], "durability": 150}, tags=["set"]),
]
W("items.json", items)

# ---------------------------------------------------------------- recipes
# Recipes (operations, materials, dice) and crafting balance live in make_recipes.py.
import make_recipes
W("recipes.json", make_recipes.recipes)
W("crafting.json", make_recipes.crafting)

# ---------------------------------------------------------------- skills & upgrades
W("skills.json", {
 "curve": {"base": 60, "exp": 1.45, "max_level": 20},
 "skills": [
  {"id": "smithing", "name": "Smithing", "desc": "Forging weapons and armour. Widens skill-check zones at smithing stations."},
  {"id": "mining", "name": "Mining", "desc": "Extracting ore. Improves expedition yields at mines."},
  {"id": "alchemy", "name": "Alchemy", "desc": "Oils, potions, reagents and coatings."},
  {"id": "runecraft", "name": "Runecraft", "desc": "Cutting, engraving and tuning runestones."},
  {"id": "travelling", "name": "Travelling", "desc": "Scouting, trading and transport. Shortens and secures expeditions."},
  {"id": "relic_hunting", "name": "Relic Hunting", "desc": "Salvage and ancient discoveries."},
  {"id": "arcane_metalwork", "name": "Arcane Metalworking", "desc": "Binding magic into mithril and adamantine.", "advanced": True},
  {"id": "enchanted_stitching", "name": "Enchanted Stitching", "desc": "Leatherwork and enchanted textiles.", "advanced": True}
 ],
 "work_skills": ["mining", "alchemy", "runecraft", "smithing", "travelling", "relic_hunting"]
})
W("upgrades.json", [
 {"id": "alchemy_kit", "name": "Alchemist's Kit", "cost": 120, "desc": "Fine glassware and a copper still. Wider precision zones at all Alchemy stations.", "requires": {}},
 {"id": "runewright_tools", "name": "Runewright's Tools", "cost": 160, "desc": "Dwarf-made chisels and a tuning fork. Wider precision zones at all Runecrafting stations.", "requires": {}},
 {"id": "arcane_foundry", "name": "Arcane Foundry", "cost": 600, "desc": "Leyline tap and warded crucible. Unlocks Arcane Metalworking.", "requires": {"skill": ["runecraft", 3], "flag": "found_mithril"}},
 {"id": "display_cases", "name": "Glass Display Cases", "cost": 90, "desc": "Customers pay a little more for well-presented stock (+10% prices).", "requires": {}},
 {"id": "second_anvil_hook", "name": "Apprentice Hooks", "cost": 60, "desc": "Hirelings produce 15% more workshop output.", "requires": {}}
])

# ---------------------------------------------------------------- destinations / loot
# threats: what an expedition meets. kind decides which gear helps: weak = damage type that hurts
# it most (fire/frost/magic), resist = damage type it shrugs off. power/dmg scale the danger.
def T(name, kind, power, dmg, weak="", resist=""):
    return dict(name=name, kind=kind, power=power, dmg=dmg, weak=weak, resist=resist)
W("destinations.json", [
 {"id": "ironroot_mine", "name": "Ironroot Mine", "exit": "north", "kind": "mining", "days": [1, 2], "danger": 1, "skill": "mining", "loot": "mine", "desc": "Old dwarf-cut galleries north of the village. Iron, coal, gems and the odd vein of silver.",
  "threats": [T("cave spiders", "beast", 8, 4, "fire"), T("a rockfall", "hazard", 6, 6), T("tunnel goblins", "bandit", 10, 5)]},
 {"id": "whisperwood", "name": "Whisperwood", "exit": "west", "kind": "scouting", "days": [1, 2], "danger": 2, "skill": "travelling", "loot": "forest", "desc": "Herbs, hides and wolves. Scouting here finds the herb-wives who sell to smiths.",
  "threats": [T("a wolf pack", "beast", 14, 6, "fire"), T("a wild boar", "beast", 16, 8), T("bandit scouts", "bandit", 14, 6)], "discovers": "supplier_herbalist"},
 {"id": "highmarsh_road", "name": "Highmarsh Road", "exit": "east", "kind": "trade", "days": [2, 3], "danger": 2, "skill": "travelling", "loot": "trade", "desc": "The trade road to Highmarsh. Buy materials, sell your goods — bandits on the bad stretches.",
  "threats": [T("road bandits", "bandit", 16, 7), T("a bog wraith", "spirit", 18, 6, "magic", "physical"), T("marsh hounds", "beast", 12, 6, "fire")], "discovers": "supplier_highmarsh"},
 {"id": "barrow_fields", "name": "Barrow Fields", "exit": "south", "kind": "relics", "days": [2, 3], "danger": 4, "skill": "relic_hunting", "loot": "barrow", "desc": "Burial mounds full of grave-goods, sealed relics — and the things that guard them.",
  "threats": [T("barrow wights", "undead", 26, 10, "fire", "frost"), T("a grave guardian", "construct", 30, 12, "frost"), T("restless dead", "undead", 22, 9, "fire")]},
 {"id": "deep_ironroot", "name": "Deep Ironroot", "exit": "north", "kind": "mining", "days": [3, 4], "danger": 6, "skill": "mining", "loot": "deep_mine", "desc": "Below the old workings. Mithril, adamantine, starstone — and whatever drove the dwarves out.", "requires_flag": "delve_map",
  "threats": [T("a stone golem", "construct", 40, 16, "frost", "fire"), T("shadow crawlers", "spirit", 34, 12, "fire", "physical"), T("a dwarf-king's revenant", "undead", 44, 16, "fire", "frost")]}
])
W("suppliers.json", {
 "_doc": "What a trade run can buy once a supplier is known (flag), at base prices; travelling skill haggles them down.",
 "village": [["ore_iron", 6], ["coal", 3], ["leather_hide", 7], ["thread_linen", 4], ["reagent_salt", 7]],
 "supplier_herbalist": [["herb_emberleaf", 8], ["herb_moonwort", 8], ["reagent_salt", 6]],
 "supplier_highmarsh": [["ingot_steel", 30], ["ore_silver", 18], ["thread_ethereal", 48], ["gem_garnet", 40], ["gem_sapphire", 52], ["ore_mithril", 110]]
})
W("loot_tables.json", {
 "_doc": "rolls: number of items; entries: [item_id, weight, [min,max] qty]; rarity_bias raises chances of rare/legendary equipment rolls.",
 "mine": {"rolls": [3, 5], "entries": [["ore_iron", 40, [2, 5]], ["coal", 30, [2, 5]], ["ore_copper", 12, [1, 3]], ["ore_silver", 8, [1, 2]], ["runestone_blank", 7, [1, 1]], ["gem_garnet", 5, [1, 1]], ["gem_moonstone", 3, [1, 1]], ["ore_mithril", 2, [1, 1]], ["relic_map", 1, [1, 1]]], "skill_entries": {"3": [["gem_sapphire", 4, [1, 1]]], "5": [["ore_mithril", 4, [1, 2]]]}},
 "deep_mine": {"rolls": [4, 6], "entries": [["ore_mithril", 30, [1, 3]], ["ore_silver", 20, [1, 3]], ["runestone_blank", 18, [1, 2]], ["ore_adamantine", 8, [1, 2]], ["gem_sapphire", 8, [1, 1]], ["gem_starstone", 3, [1, 1]], ["starmetal_fragment", 3, [1, 1]], ["equip:weapon", 6, [1, 1]], ["relic_unknown_arms", 4, [1, 1]], ["relic_crown_shard", 2, [1, 1]]], "rarity_bias": 25, "skill_entries": {"6": [["gem_starstone", 6, [1, 1]]]}},
 "forest": {"rolls": [3, 4], "entries": [["herb_emberleaf", 30, [1, 3]], ["herb_moonwort", 30, [1, 3]], ["leather_hide", 25, [1, 2]], ["thread_linen", 10, [1, 2]], ["equip:any", 5, [1, 1]]]},
 "trade": {"rolls": [2, 4], "entries": [["reagent_salt", 25, [1, 3]], ["thread_linen", 20, [2, 4]], ["thread_ethereal", 8, [1, 1]], ["leather_cured", 20, [1, 2]], ["coal", 20, [2, 4]], ["equip:any", 7, [1, 1]]]},
 "barrow": {"rolls": [3, 5], "entries": [["relic_coin", 20, [1, 2]], ["relic_idol", 10, [1, 1]], ["runestone_blank", 12, [1, 2]], ["equip:any", 24, [1, 1]], ["relic_unknown_arms", 9, [1, 1]], ["relic_unknown_tablet", 8, [1, 1]], ["relic_unknown_reliquary", 6, [1, 1]], ["relic_crown_shard", 3, [1, 1]], ["ore_silver", 12, [1, 2]]], "rarity_bias": 15, "skill_entries": {"4": [["relic_unknown_reliquary", 6, [1, 1]]]}},
 "relic_reveal": {"rolls": [1, 1], "entries": [["equip:ancient", 40, [1, 1]], ["starmetal_fragment", 18, [1, 2]], ["gem_starstone", 10, [1, 1]], ["gem_moonstone", 12, [1, 2]], ["recipe_scroll", 20, [1, 1]]], "rarity_bias": 30},
 "gratitude": {"rolls": [1, 1], "entries": [["relic_unknown_reliquary", 40, [1, 1]], ["relic_unknown_arms", 30, [1, 1]], ["gem_starstone", 15, [1, 1]], ["recipe_scroll", 15, [1, 1]]]},
 "gift": {"rolls": [1, 2], "entries": [["potion_healing", 30, [1, 2]], ["runestone_ember", 10, [1, 1]], ["relic_coin", 15, [1, 1]], ["herb_moonwort", 25, [2, 3]], ["equip:jewel", 12, [1, 1]], ["ore_silver", 15, [1, 2]]], "rarity_bias": 10},
 "reward": {"rolls": [2, 3], "entries": [["equip:any", 35, [1, 1]], ["runestone_ward", 15, [1, 1]], ["relic_idol", 10, [1, 1]], ["ore_mithril", 10, [1, 1]], ["ingot_steel", 25, [1, 2]]], "rarity_bias": 30},
 "start_bag": {"rolls": [5, 5], "entries": [["ore_iron", 30, [4, 4]], ["coal", 30, [3, 3]], ["leather_hide", 20, [2, 2]], ["ore_silver", 10, [2, 2]], ["equip:legendary_demo", 10, [1, 1]]]}
})
print("data ok")

# ---------------------------------------------------------------- characters
# look: build heavy|average|slim|dwarf|halfling|orc ; hair: bald_fringe|short|long|ponytail|braid|bun|hood|curly|mohawk|cropped
# beard: none|stubble|short|long|braided ; armor: none|leather|chain|plate|robe|apron ; back: none|shield|quiver|staff|pack|lute|cloak_only
# hand: none|sword|bow|staff|axe|mace|dagger|hammer|lute|basket|tankard ; colours are role names from the 80:20 palette or hex
def ch(id, name, kind, look, **kw):
    d = dict(id=id, name=name, kind=kind, look=look, sprite=f"chars/{id}", portrait=f"portraits/{id}")
    d.update(kw); return d
L = lambda **k: k
chars = [
 ch("player", "Brannoc Ironhand", "player", L(build="heavy", female=False, skin="#d9a87e", hair="bald_fringe", hair_col="#a8a094", beard="braided", beard_col="#c8c2b4",
    armor="apron", shirt="#cdbd9a", cloak=None, back="none", hand="hammer", extras=["eyepatch", "scalp_scar", "pauldron"]),
    age=58, title="Retired adventurer, master smith", personality="Gruff, patient, dry humour; knows too much about how adventurers die."),
 ch("borin", "Borin Flintbeard", "hireling", L(build="dwarf", female=False, skin="#c99a76", hair="short", hair_col="#7a3e22", beard="long", beard_col="#8a4a28",
    armor="leather", shirt="#6e5a44", cloak=None, back="pack", hand="pick", extras=["helmet_miner"]),
    age=141, title="Miner & procurer", personality="Blunt, loyal, superstitious about tunnels; sings when the ore is good.",
    skills={"mining": 5, "travelling": 2, "smithing": 2, "relic_hunting": 1, "alchemy": 0, "runecraft": 0}, wage=6),
 # adventurers (adults). romance = adult women adventurers who may become partners
 ch("mira", "Mira Pell", "adventurer", L(build="slim", female=True, skin="#e2b48e", hair="braid", hair_col="#8a4a24", beard="none", armor="leather", shirt="#5e6e4a",
    cloak="#4e6a44", back="quiver", hand="bow", extras=[]), age=24, cls="Ranger", level=3, gold=60, romance=True,
    personality="Quick, warm, stubborn; wants to prove she is more than the grocer's girl.", family={"aldric": "father"}, home="grocery"),
 ch("sigrun", "Sigrun Halvard", "adventurer", L(build="average", female=True, skin="#e8c8a8", hair="ponytail", hair_col="#d8c088", beard="none", armor="plate", shirt="#6a7486",
    cloak="#7e2c30", back="shield", hand="sword", extras=[]), age=31, cls="Fighter", level=5, gold=140, romance=True,
    personality="Plain-spoken shield-maiden; respects good steel and better honesty."),
 ch("elowen", "Elowen Vey", "adventurer", L(build="slim", female=True, skin="#f0dcc8", hair="long", hair_col="#d8d0c0", beard="none", armor="robe", shirt="#3e4a6e",
    cloak="#2e3450", back="none", hand="staff", extras=["pointed_ears"]), age=29, cls="Wizard", level=4, gold=200, romance=True,
    personality="Dry, curious, faintly superior; fascinated by arcane metal."),
 ch("kestra", "Kestra Dunmore", "adventurer", L(build="slim", female=True, skin="#c89070", hair="cropped", hair_col="#2a1e16", beard="none", armor="leather", shirt="#3a3430",
    cloak="#2a2622", back="none", hand="dagger", extras=["hood_down"]), age=27, cls="Rogue", level=3, gold=90, romance=True,
    personality="Sharp tongue, soft spot for strays; owes money to the wrong people.", family={"tobin": "brother"}),
 ch("garrick", "Garrick Stone", "adventurer", L(build="average", female=False, skin="#d8a882", hair="short", hair_col="#5a4030", beard="short", beard_col="#5a4030", armor="plate",
    shirt="#c8c0a8", cloak="#d8d0b8", back="shield", hand="mace", extras=[]), age=35, cls="Paladin", level=6, gold=180,
    personality="Earnest and kind; writes to his mother every week.", family={"martha": "mother"}),
 ch("tomas", "Brother Tomas", "adventurer", L(build="heavy", female=False, skin="#b88a66", hair="bald_fringe", hair_col="#3a2e24", beard="stubble", armor="robe",
    shirt="#8a6e48", cloak=None, back="pack", hand="mace", extras=[]), age=42, cls="Cleric", level=4, gold=70,
    personality="Jovial healer with a gambling problem."),
 ch("varn", "Varn Ashfang", "adventurer", L(build="orc", female=False, skin="#8a9a72", hair="mohawk", hair_col="#1e1a16", beard="none", armor="leather", shirt="#5a3a26",
    cloak=None, back="none", hand="axe", extras=["tusks"]), age=29, cls="Barbarian", level=5, gold=50,
    personality="Loud, generous, terrible with money; breaks axes for fun."),
 ch("pip", "Pip Underbough", "adventurer", L(build="halfling", female=False, skin="#e0b48e", hair="curly", hair_col="#6a3e1e", beard="none", armor="leather", shirt="#7e5a8a",
    cloak="#5a3e6a", back="lute", hand="dagger", extras=[]), age=33, cls="Bard", level=2, gold=110,
    personality="Collects stories and gossip; will tell anyone anything for a drink."),
 # villagers
 ch("aldric", "Aldric Pell", "villager", L(build="heavy", female=False, skin="#e0b090", hair="short", hair_col="#9a948a", beard="short", beard_col="#9a948a", armor="apron",
    shirt="#a89060", cloak=None, back="none", hand="basket", extras=[]), age=56, title="Grocer", personality="Proud, fussy, devoted to his daughter Mira.",
    family={"mira": "daughter"}, home="grocery", work="grocery"),
 ch("hilde", "Hilde Brask", "villager", L(build="heavy", female=True, skin="#e8bc98", hair="bun", hair_col="#b06a3a", beard="none", armor="apron",
    shirt="#8a3e2c", cloak=None, back="none", hand="tankard", extras=[]), age=49, title="Innkeeper of the Tipsy Wyvern", personality="Loud laugh, long memory, waters nobody's ale.",
    home="inn", work="inn"),
 ch("martha", "Old Martha", "villager", L(build="average", female=True, skin="#e6c4a8", hair="bun", hair_col="#e0dcd4", beard="none", armor="none",
    shirt="#5e5a6e", cloak="#4a4658", back="none", hand="none", extras=[]), age=71, title="Widow", personality="Sharp eyes, sharper tongue; worries about her son Garrick.",
    family={"garrick": "son"}, home="house_martha"),
 ch("tobin", "Tobin Dunmore", "villager", L(build="average", female=False, skin="#c48a66", hair="short", hair_col="#2a1e16", beard="stubble", armor="apron",
    shirt="#7a6a50", cloak=None, back="none", hand="hammer", extras=[]), age=30, title="Carpenter", personality="Quiet, careful, embarrassed by his sister's debts.",
    family={"kestra": "sister"}, home="house_tobin", work="house_tobin"),
 ch("wenna", "Wenna", "villager", L(build="slim", female=True, skin="#ecc6a4", hair="ponytail", hair_col="#b8783a", beard="none", armor="apron",
    shirt="#a8b090", cloak=None, back="none", hand="tankard", extras=[]), age=23, title="Barmaid", personality="Cheerful; hears everything at the inn.", home="house_wenna", work="inn"),
 ch("oswin", "Father Oswin", "villager", L(build="slim", female=False, skin="#e4c0a0", hair="short", hair_col="#d8d4cc", beard="long", beard_col="#d8d4cc", armor="robe",
    shirt="#d8ccb0", cloak=None, back="none", hand="none", extras=[]), age=67, title="Priest of the Dawn", personality="Gentle, tired, buries too many adventurers.",
    home="house_oswin", work="house_oswin"),
 ch("jory", "Jory Thatch", "villager", L(build="average", female=False, skin="#d49a72", hair="hood", hair_col="#6a5030", beard="short", beard_col="#6a5030", armor="none",
    shirt="#6e7a4a", cloak=None, back="none", hand="basket", extras=[]), age=44, title="Farmer", personality="Talks about weather; secretly superstitious.", home="house_jory"),
 ch("eda", "Eda Rook", "villager", L(build="average", female=True, skin="#b67c58", hair="long", hair_col="#1e1612", beard="none", armor="none",
    shirt="#6e4a6a", cloak=None, back="none", hand="basket", extras=[]), age=38, title="Washerwoman", personality="Gossip with a good heart.", home="house_eda"),
 # the Velvet Lantern (adults; social interaction only, discreet fade-to-black)
 ch("rosalind", "Madam Rosalind", "companion", L(build="average", female=True, skin="#e8c0a0", hair="bun", hair_col="#3a1e1a", beard="none", armor="robe",
    shirt="#6e1e2a", cloak=None, back="none", hand="none", extras=[]), age=45, title="Keeper of the Velvet Lantern", personality="Elegant, shrewd, trades in secrets.", home="inn_upstairs"),
 ch("lysa", "Lysa", "companion", L(build="slim", female=True, skin="#d4a07c", hair="long", hair_col="#e0c070", beard="none", armor="robe",
    shirt="#8a2e44", cloak=None, back="none", hand="none", extras=[]), age=26, title="Companion", personality="Witty; listens more than she speaks.", home="inn_upstairs"),
 ch("celeste", "Celeste", "companion", L(build="slim", female=True, skin="#a8704e", hair="curly", hair_col="#1a1210", beard="none", armor="robe",
    shirt="#3e2a5a", cloak=None, back="none", hand="none", extras=[]), age=30, title="Companion", personality="Sings old ballads; remembers every adventurer's name.", home="inn_upstairs"),
]
# applicant appearance variants (recruitment uses these with generated names/skills)
for i, (b, f, hair, hc, beard, sk, shirt) in enumerate([
    ("average", False, "short", "#4a3020", "stubble", "#d8a882", "#6a5a40"),
    ("slim", True, "ponytail", "#2a1e16", "none", "#c48a66", "#5e6e4a"),
    ("slim", True, "long", "#e0d0a0", "none", "#f0dcc8", "#4a5a7a"),
    ("halfling", False, "curly", "#8a5a2a", "none", "#e0b48e", "#8a6a3a"),
    ("orc", False, "mohawk", "#2a2018", "none", "#8a9a72", "#5a4a3a"),
    ("dwarf", True, "braid", "#b05a2a", "none", "#d8a882", "#6e4a3a")]):
    chars.append(ch(f"applicant_{i}", "Applicant", "applicant_look", L(build=b, female=f, skin=sk, hair=hair, hair_col=hc, beard=beard, beard_col=hc,
                    armor="leather" if i % 2 else "none", shirt=shirt, cloak=None, back="pack", hand="none", extras=["pointed_ears"] if i == 2 else [])))
W("characters.json", chars)
print("chars ok", len(chars))

# ---------------------------------------------------------------- props (sprite id -> px size, solid footprint fraction)
P = lambda w, h, solid=True, desc="": dict(size=[w, h], solid=solid, desc=desc)
props = {
 "shop_counter": P(256, 64, desc="long wooden shop counter, top-down, with a ledger book, scales and a coin dish"),
 "weapon_rack": P(160, 56, desc="wall weapon rack holding 4 swords/axes, seen from above"),
 "armor_stand": P(72, 88, desc="armour stand with a breastplate on it"),
 "display_table": P(128, 80, desc="display table with helmets, gloves and a shield laid out"),
 "bed": P(96, 160, desc="wooden bed with blanket and pillow"),
 "bed_fancy": P(112, 160, desc="canopy-less fancy bed with burgundy covers and cushions (Velvet Lantern)"),
 "table_round": P(96, 96, desc="round tavern table with tankards and a candle"),
 "table_long": P(192, 80, desc="long trestle table with plates and tankards"),
 "chair": P(40, 40), "stool": P(32, 32),
 "bench": P(160, 36),
 "bar_counter": P(320, 64, desc="tavern bar counter with tankards and a tap"),
 "keg": P(56, 56), "barrel": P(56, 56), "crate": P(56, 56), "sack": P(48, 48),
 "shelf": P(128, 40, desc="shelf with jars and bottles"),
 "bookshelf": P(128, 40),
 "wardrobe": P(112, 48), "chest": P(72, 56, desc="iron-bound chest"),
 "fireplace": P(128, 72, desc="stone hearth/fireplace set into a wall, burning"),
 "rug_red": P(192, 128, solid=False), "rug_brown": P(160, 112, solid=False),
 "stairs_up": P(96, 128, solid=False, desc="wooden staircase seen from above"),
 "stairs_down": P(96, 128, solid=False),
 "lantern_post": P(48, 48, desc="iron lantern post seen from above (lamp head visible)"),
 "candle": P(24, 24, solid=False),
 "well": P(112, 112, desc="stone well with small roof frame and bucket"),
 "notice_board": P(144, 72, desc="village notice board with pinned papers, top-down"),
 "market_stall": P(192, 128, desc="market stall with striped burgundy/cream awning"),
 "cart": P(128, 96, desc="hand cart with hay"),
 "beer_table": P(128, 96, desc="outdoor beer-garden table with benches"),
 "sign_smithy": P(80, 48, desc="hanging sign: anvil emblem"),
 "sign_inn": P(80, 48, desc="hanging sign: wyvern holding tankard"),
 "sign_grocer": P(80, 48, desc="hanging sign: wheat sheaf and apple"),
 "fence_h": P(64, 24), "fence_v": P(24, 64),
 "bush": P(80, 80), "bush_flower": P(80, 80),
 "rock_a": P(64, 48), "rock_b": P(88, 64),
 "flowers": P(64, 64, solid=False),
 "tree_oak_a": P(224, 224), "tree_oak_b": P(192, 192), "tree_pine": P(176, 176), "tree_small": P(128, 128),
 "haybale": P(64, 64), "coal_pile": P(80, 64), "ore_pile": P(80, 64), "woodpile": P(96, 64),
 "produce_crate": P(64, 64, desc="crate of apples/cabbages"),
 "grain_sacks": P(80, 64),
 "altar": P(128, 64, desc="small chapel altar with candles"),
 "pew": P(160, 40),
 "washtub": P(72, 72),
 "eggs_splat": P(96, 64, solid=False, desc="broken egg splatter decal (vandalism)"),
 "gravestone": P(40, 48),
 "loot_pile": P(64, 48, solid=False, desc="dropped expedition bag on the floor"),
 "door_mat": P(96, 40, solid=False),
 "workbench": P(160, 64, desc="carpenter's workbench with tools"),
 "dummy_target": P(64, 64, desc="training dummy"),
 # ---- interior decor pass (drawn by tools/art/make_interiors.py)
 "tool_wall": P(160, 48, desc="wall-mounted rack of hammers, tongs and files (smithy)"),
 "iron_bars": P(96, 64, desc="stack of iron bars and billets"),
 "soot_decal": P(192, 160, solid=False, desc="floor soot/char stains around a forge (semi-transparent decal)"),
 "rune_shelf": P(128, 48, desc="shelf of carved runestones with faint pale-gold glow marks"),
 "rune_glyph_decal": P(160, 160, solid=False, desc="faint inscribed rune circle on the floor"),
 "stone_blocks": P(80, 72, desc="raw runestone blocks and slabs"),
 "herb_rack": P(160, 48, desc="rack of drying herb bundles"),
 "bottle_shelf": P(128, 48, desc="shelf with muted green/amber/red bottles"),
 "ingredient_crates": P(96, 80, desc="crates of roots, mushrooms and salts"),
 "spill_decal": P(96, 72, solid=False, desc="coloured alchemical stains on the floor"),
 "arcane_rack": P(112, 56, desc="rack of charged metal bars with a restrained violet glow"),
 "arcane_glyph_decal": P(192, 192, solid=False, desc="faint violet floor sigils"),
 "hide_rack": P(128, 96, desc="stretched hide laced into a wooden frame"),
 "pattern_board": P(128, 40, desc="wall board with hanging leather patterns"),
 "thread_spools": P(72, 56, desc="tray of thread spools incl. one pale ethereal spool"),
 "leather_bundle": P(80, 56, desc="rolled leather and offcuts"),
 "desk_ledger": P(144, 80, desc="writing desk with open ledger, quill, candle, papers and a small keepsake"),
 "dining_table": P(192, 96, desc="dining table set with plates, bread and tankards"),
 "cupboard": P(112, 48, desc="kitchen cupboard with crocks on top"),
 "kitchen_stove": P(112, 80, desc="iron kitchen stove on a stone hearth with a pot"),
 "bed_double": P(128, 160, desc="double bed with patchwork quilt"),
 "dresser": P(96, 48, desc="dresser with wash basin and jug"),
 "bath_tub": P(128, 80, desc="wooden bath tub with water and towel"),
 "trophy_wall": P(128, 40, desc="mounted old adventuring trophies: crossed swords, battered shield, horn"),
 "nightstand": P(48, 48, desc="nightstand with candle and book"),
 "bar_shelf": P(192, 40, desc="behind-the-bar shelf of bottles and mugs"),
 # ---- shop-front waiting area / decor (drawn by tools/art/make_props.py)
 "waiting_seat": P(64, 64, desc="single outdoor wooden seat with a burgundy cushion"),
 "waiting_awning": P(192, 64, desc="small striped awning on two poles with a hanging hourglass sign (waiting area)"),
 "craft_display": P(192, 96, desc="display stand of example crafted equipment: swords in a rack, cuirass, helm and shield"),
 "flower_patch_a": P(48, 48, solid=False, desc="small flower clump rooted on the bottom edge (sway shader)"),
 "flower_patch_b": P(48, 48, solid=False, desc="small flower clump rooted on the bottom edge (sway shader)"),
}
W("props.json", props)
print("props ok", len(props))
