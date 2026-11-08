"""Generates game/data/recipes.json and game/data/crafting.json — the crafting process data.
Run: python3 tools/data/make_recipes.py

A recipe is a sequence of OPERATIONS. Each operation happens at one physical station, has a name
the player sees ("Draw out the blade"), a number of precision checks and a weight in the final
craftsmanship. The same station may appear several times (heat → hammer → re-heat → hammer).
Simple items use one or two operations; masterworks use many.

crafting.json holds every tunable number: material factors, the skill/difficulty curve, the check
quality curve, the dice attributes and the rarity formula + thresholds (rarity stays configurable).
"""
import json, os
D = os.path.join(os.path.dirname(__file__), "..", "..", "data")


def W(name, obj):
    with open(os.path.join(D, name), "w") as f:
        json.dump(obj, f, indent=1, ensure_ascii=False)


# ---------------------------------------------------------------- tunables
crafting = {
 "_doc": "Crafting balance. Rarity score = quality*w.quality + fortune*w.fortune + material/rune bonus "
         "(+ masterwork bonus when quality >= masterwork.quality). Thresholds are inclusive lower bounds.",
 "rarity": {
  "weights": {"quality": 0.75, "fortune": 0.35},
  "thresholds": {"magic": 68, "rare": 88, "legendary": 112},
  "masterwork": {"quality": 115, "bonus": 26, "label": "Masterwork"},
  "runestone_bonus": 8,
 },
 "check": {
  "_doc": "Continuous precision curve. Zone centre = peak, zone edge = edge, misses fall to floor.",
  "peak": 120.0, "edge": 70.0, "curve": 1.3, "miss_hi": 65.0, "floor": 10.0, "timeout": 8.0,
 },
 "skill": {
  "_doc": "Skill eases the check (wider zone, slower needle) and adds a little quality, "
          "but the player still has to stop the needle.",
  "zone_per_level": 1.4, "speed_ease_per_level": 0.015, "speed_ease_max": 0.3,
  "quality_per_level": 0.4,
  "difficulty_zone": 0.06, "difficulty_speed": 0.05,
  "upgrade_zone": {"runewright_tools": ["runecraft", 5], "alchemy_kit": ["alchemy", 5]},
  "xp_expert_gap": 5, "xp_expert_mult": 0.4,
 },
 "dice": {
  "edge": {"label": "Edge", "stat": "attack", "desc": "the blade's bite (attack)"},
  "guard": {"label": "Guard", "stat": "protection", "desc": "how well it turns a blow (protection)"},
  "temper": {"label": "Temper", "stat": "durability", "desc": "how long it lasts (durability)"},
  "fortune": {"label": "Fortune", "stat": "rarity", "desc": "forge-luck that feeds rarity (d100)"},
  "purity": {"label": "Purity", "stat": "yield", "desc": "purity of the batch (a 6 adds a unit)"},
  "potency": {"label": "Potency", "stat": "potency", "desc": "strength of the brew"},
  "resonance": {"label": "Resonance", "stat": "potency", "desc": "how clearly the rune sings"},
  "spellweave": {"label": "Spellweave", "stat": "magic", "desc": "how much magic the metal holds"},
 },
 "minigames": {
  "_doc": "Specialised skill checks per station (default: the circular precision ring). "
          "type: align | edge | multihit | rune | rings. Rings: dir in/out, fx look.",
  "bellows": {"type": "align"},
  "grinding_wheel": {"type": "edge"},
  "rune_polishing_wheel": {"type": "edge"},
  "rune_engraving_stand": {"type": "rune"},
  "resonance_pedestal": {"type": "multihit", "targets": 5},
  "embroidery_frame": {"type": "multihit", "targets": 5},
  "thread_spinner": {"type": "multihit", "targets": 4},
  "spellbinding_array": {"type": "multihit", "targets": 5},
  "infusion_rack": {"type": "multihit", "targets": 4},
  "mortar_station": {"type": "rings", "dir": "in", "fx": "mixing"},
  "cauldron": {"type": "rings", "dir": "in", "fx": "brewing"},
  "alembic": {"type": "rings", "dir": "out", "fx": "distilling"},
  "reagent_table": {"type": "rings", "dir": "out", "fx": "volatile"},
 },
 "materials": {
  "iron": {"name": "Iron", "stat": 1.0, "durability": 1.0, "difficulty": 0, "rarity_bonus": 0},
  "steel": {"name": "Steel", "stat": 1.18, "durability": 1.3, "difficulty": 1, "rarity_bonus": 4},
  "silver": {"name": "Silver", "stat": 1.05, "durability": 0.8, "difficulty": 1, "rarity_bonus": 3},
  "mithril": {"name": "Charged Mithril", "stat": 1.35, "durability": 1.5, "difficulty": 3, "rarity_bonus": 10},
  "leather": {"name": "Cured Leather", "stat": 1.0, "durability": 0.9, "difficulty": 0, "rarity_bonus": 0},
  "ethereal": {"name": "Leather & Ethereal Thread", "stat": 1.15, "durability": 1.0, "difficulty": 2, "rarity_bonus": 6},
  "runestone": {"name": "Runestone", "stat": 1.0, "durability": 1.0, "difficulty": 1, "rarity_bonus": 4},
  "herbal": {"name": "Herbs & Reagents", "stat": 1.0, "durability": 1.0, "difficulty": 0, "rarity_bonus": 0},
  "ore": {"name": "Ore", "stat": 1.0, "durability": 1.0, "difficulty": 0, "rarity_bonus": 0},
  "jewel": {"name": "Silver & Gemstone", "stat": 1.15, "durability": 0.8, "difficulty": 1, "rarity_bonus": 8},
  "adamantine": {"name": "Charged Adamantine", "stat": 1.45, "durability": 1.8, "difficulty": 4, "rarity_bonus": 12},
  "starmetal": {"name": "Steel & Starmetal", "stat": 1.3, "durability": 1.5, "difficulty": 2, "rarity_bonus": 10},
  "bearhide": {"name": "Bear Leather", "stat": 1.1, "durability": 1.15, "difficulty": 1, "rarity_bonus": 3},
  "wyrmhide": {"name": "Wyrm Leather", "stat": 1.25, "durability": 1.4, "difficulty": 2, "rarity_bonus": 8},
  "orichalcum": {"name": "Orichalcum", "stat": 1.4, "durability": 1.6, "difficulty": 3, "rarity_bonus": 12},
  "dragonscale": {"name": "Dragon Scale & Bone", "stat": 1.6, "durability": 2.0, "difficulty": 4, "rarity_bonus": 20},
 },
}

# ---------------------------------------------------------------- dice sets
DW = {"edge": "1d20", "temper": "1d12", "fortune": "1d100"}
DA = {"guard": "1d20", "temper": "1d12", "fortune": "1d100"}
DM = {"purity": "1d6"}
DP = {"potency": "1d8", "fortune": "1d100"}
DR = {"resonance": "1d10", "fortune": "1d100"}
DX = {"edge": "1d20", "spellweave": "1d12", "temper": "1d12", "fortune": "1d100"}
DXA = {"guard": "1d20", "spellweave": "1d12", "temper": "1d12", "fortune": "1d100"}
DJ = {"resonance": "1d10", "fortune": "1d100"}
DE = {"edge": "1d20", "resonance": "1d10", "temper": "1d12", "fortune": "1d100"}


def op(station, name, checks=1, weight=1.0):
    return dict(station=station, op=name, checks=checks, weight=weight)


def rc(id, name, disc, category, material, difficulty, ops, inputs, out, qty=1, dice=None, xp=None,
       requires=None, desc="", flag="", teaches="", min_rarity=""):
    r = dict(id=id, name=name, discipline=disc, category=category, material=material,
             difficulty=difficulty, operations=ops, steps=[o["station"] for o in ops],
             inputs=inputs, output=out, qty=qty, dice=dice or {}, xp=xp or {},
             requires=requires or {}, desc=desc)
    if flag:
        r["requires_flag"] = flag   # learned from a forgotten recipe found among relics
    if teaches:
        r["teaches_flag"] = teaches  # finishing the work teaches the smith something (a knowledge flag)
    if min_rarity:
        r["min_rarity"] = min_rarity  # legendary-grade work never comes out below this rarity
    return r


recipes = [
 # ---- materials (short: one or two operations)
 rc("smelt_iron", "Smelt Iron Ingots", "classic", "material", "ore", 1,
    [op("crucible", "Melt the ore", 1), op("forge", "Cast and cool the ingots", 1)],
    {"ore_iron": 2, "coal": 1}, "ingot_iron", 2, DM, {"smithing": 12, "mining": 20}),
 rc("smelt_steel", "Fold Steel Ingot", "classic", "material", "iron", 3,
    [op("crucible", "Melt iron with carbon", 1), op("bellows", "Drive the heat up", 2, 0.7),
     op("forge", "Fold and weld the bloom", 2, 1.2)],
    {"ingot_iron": 2, "coal": 2}, "ingot_steel", 1, DM, {"smithing": 18, "mining": 24}),
 # ---- weapons
 rc("iron_longsword", "Iron Longsword", "classic", "weapon", "iron", 2,
    [op("forge", "Heat the billet", 1), op("anvil", "Draw out the blade", 2, 1.4),
     op("quench_trough", "Quench the edge", 1, 1.1), op("grinding_wheel", "Grind and sharpen", 1)],
    {"ingot_iron": 2, "leather_cured": 1}, "sword_iron", 1, DW, {"smithing": 30},
    desc="The first sword every apprentice learns."),
 rc("steel_longsword", "Steel Longsword", "classic", "weapon", "steel", 4,
    [op("forge", "Bring the steel to yellow heat", 1), op("bellows", "Hold the heat steady", 1, 0.7),
     op("anvil", "Draw and bevel the blade", 3, 1.4), op("forge", "Normalise in the coals", 1, 0.8),
     op("quench_trough", "Oil-quench the blade", 1, 1.2), op("grinding_wheel", "Hone a keen edge", 2, 1.1),
     op("stitching_table", "Wrap the grip", 1, 0.5)],
    {"ingot_steel": 2, "leather_cured": 1}, "sword_steel", 1, DW, {"smithing": 45},
    requires={"smithing": 3}, desc="Folded steel, normalised twice. Rewards a steady hand."),
 rc("steel_bastard_sword", "Steel Bastard Sword", "classic", "weapon", "steel", 8,
    [op("forge", "Heat the long billet", 2), op("anvil", "Forge the hand-and-a-half blade", 4, 1.5),
     op("quench_trough", "Interrupted quench", 2, 1.3), op("grinding_wheel", "Grind the double fuller", 2, 1.1)],
    {"ingot_steel": 3, "leather_cured": 1}, "sword_bastard", 1, DW, {"smithing": 70},
    requires={"smithing": 8}, desc="A master's blade. Only an expert can keep the long steel straight."),
 rc("hand_axe", "Hand Axe", "classic", "weapon", "iron", 1,
    [op("forge", "Heat the head", 1), op("anvil", "Punch the eye and shape the bit", 2, 1.3)],
    {"ingot_iron": 1, "coal": 1}, "axe_hand", 1, DW, {"smithing": 22}),
 rc("flanged_mace", "Flanged Mace", "classic", "weapon", "iron", 2,
    [op("forge", "Heat the head", 1), op("anvil", "Weld on the flanges", 2, 1.3),
     op("quench_trough", "Harden", 1)],
    {"ingot_iron": 2, "coal": 1}, "mace_flanged", 1, DW, {"smithing": 28}),
 # ---- armour
 rc("iron_cuirass", "Iron Cuirass", "classic", "armour", "iron", 3,
    [op("forge", "Heat the plates", 1), op("anvil", "Dish the breastplate", 3, 1.4),
     op("forge", "Re-heat for the backplate", 1, 0.8), op("anvil", "Planish and roll the edges", 2, 1.2),
     op("quench_trough", "Temper the plates", 1), op("stitching_table", "Rivet the leather straps", 1, 0.7)],
    {"ingot_iron": 3, "leather_cured": 1}, "cuirass_iron", 1, DA, {"smithing": 40}),
 rc("iron_helm", "Iron Helm", "classic", "armour", "iron", 2,
    [op("forge", "Heat the skull plate", 1), op("anvil", "Raise the dome", 2, 1.3),
     op("grinding_wheel", "Smooth the brow", 1)],
    {"ingot_iron": 1, "leather_cured": 1}, "helm_iron", 1, DA, {"smithing": 20}),
 rc("round_shield", "Round Shield", "classic", "armour", "iron", 1,
    [op("forge", "Heat the boss", 1), op("anvil", "Dome the boss and band the rim", 1, 1.2)],
    {"ingot_iron": 1, "leather_cured": 1}, "shield_round", 1, DA, {"smithing": 18}),
 rc("silver_band", "Silver Band", "classic", "jewellery", "silver", 2,
    [op("crucible", "Melt the silver", 1), op("anvil", "Draw and close the band", 1, 1.2),
     op("grinding_wheel", "Polish to a shine", 1)],
    {"ore_silver": 2}, "ring_silver", 1, {"fortune": "1d100"}, {"smithing": 20}, desc="A ring fit for a proposal."),
 # ---- leather
 rc("cure_leather", "Cure Leather", "stitching", "material", "leather", 1,
    [op("leather_vat", "Soak and tan the hides", 1)],
    {"leather_hide": 2}, "leather_cured", 2, DM, {"enchanted_stitching": 10}),
 rc("leather_jerkin", "Leather Jerkin", "stitching", "armour", "leather", 2,
    [op("leather_vat", "Oil and soften the panels", 1, 0.8), op("stitching_table", "Cut the pattern", 1),
     op("stitching_table", "Saddle-stitch the seams", 2, 1.3)],
    {"leather_cured": 3, "thread_linen": 1}, "jerkin_leather", 1, DA, {"enchanted_stitching": 28}),
 rc("leather_boots", "Leather Boots", "stitching", "armour", "leather", 1,
    [op("stitching_table", "Last and stitch the boots", 2)],
    {"leather_cured": 2, "thread_linen": 1}, "boots_leather", 1, DA, {"enchanted_stitching": 18}),
 rc("leather_gloves", "Leather Gloves", "stitching", "armour", "leather", 1,
    [op("stitching_table", "Cut and stitch the fingers", 1)],
    {"leather_cured": 1, "thread_linen": 1}, "gloves_leather", 1, DA, {"enchanted_stitching": 14}),
 rc("leather_belt", "Leather Belt", "stitching", "armour", "leather", 1,
    [op("stitching_table", "Cut, edge and punch", 1)],
    {"leather_cured": 1}, "belt_leather", 1, DA, {"enchanted_stitching": 10}),
 rc("warded_gloves", "Warded Gloves", "stitching", "armour", "ethereal", 5,
    [op("thread_spinner", "Spin ethereal thread", 1), op("stitching_table", "Stitch the gloves", 2),
     op("embroidery_frame", "Embroider the ward sigils", 2, 1.3), op("fitting_mannequin", "Fit and balance", 1)],
    {"leather_cured": 2, "thread_ethereal": 1, "runestone_ward": 1}, "gloves_warded", 1, DA,
    {"enchanted_stitching": 60}, requires={"enchanted_stitching": 3}),
 # ---- alchemy
 rc("whetstone_oil", "Whetstone Oil", "alchemy", "alchemy", "herbal", 1,
    [op("mortar_station", "Grind emberleaf with quicksalt", 1), op("alembic", "Distil the oil", 1)],
    {"herb_emberleaf": 1, "reagent_salt": 1}, "oil_whetstone", 2, DP, {"alchemy": 15}),
 rc("healing_draught", "Healing Draught", "alchemy", "alchemy", "herbal", 2,
    [op("mortar_station", "Bruise the moonwort", 1), op("cauldron", "Simmer the draught", 2, 1.2),
     op("infusion_rack", "Steep and bottle", 1)],
    {"herb_moonwort": 2}, "potion_healing", 2, DP, {"alchemy": 20}),
 rc("flame_coating", "Flame Coating", "alchemy", "alchemy", "herbal", 3,
    [op("mortar_station", "Grind emberleaf and coal", 1), op("reagent_table", "Separate the volatile oil", 1, 1.1),
     op("cauldron", "Reduce to a coating", 2, 1.2)],
    {"herb_emberleaf": 2, "coal": 1}, "coating_flame", 1, DP, {"alchemy": 26},
    desc="Brushed onto a blade before a hunt: it burns on the strike."),
 # ---- runecraft
 rc("ember_runestone", "Ember Runestone", "runecraft", "runestone", "runestone", 3,
    [op("rune_cutting_bench", "Cleave the blank", 1), op("rune_engraving_stand", "Engrave the ember rune", 2, 1.4),
     op("rune_cleansing_basin", "Wash away the chaos", 1, 0.8), op("resonance_pedestal", "Tune the hum", 2, 1.2),
     op("rune_polishing_wheel", "Polish to a mirror", 1)],
    {"runestone_blank": 1, "herb_emberleaf": 1}, "runestone_ember", 1, DR, {"runecraft": 35}),
 rc("ward_runestone", "Ward Runestone", "runecraft", "runestone", "runestone", 2,
    [op("rune_cutting_bench", "Cleave the blank", 1), op("rune_engraving_stand", "Engrave the ward rune", 2, 1.4),
     op("resonance_pedestal", "Tune the hum", 1, 1.2)],
    {"runestone_blank": 1, "reagent_salt": 1}, "runestone_ward", 1, DR, {"runecraft": 30}),
 # ---- arcane (gated by the Arcane Foundry)
 rc("charge_mithril", "Charge Mithril", "arcane", "material", "ore", 4,
    [op("arcane_crucible", "Melt mithril in warded fire", 2), op("leyline_conductor", "Draw the leyline", 1),
     op("aetheric_stabilizer", "Stabilise the charge", 1)],
    {"ore_mithril": 2, "coal": 2}, "ingot_mithril", 1, DM, {"arcane_metalwork": 40, "mining": 30}),
 rc("mithril_runeblade", "Mithril Runeblade", "arcane", "weapon", "mithril", 7,
    [op("forge", "Heat the charged billet", 1), op("arcane_crucible", "Re-melt the fuller channel", 1),
     op("spellbinding_array", "Bind the spell pattern", 2, 1.3), op("arcane_anvil", "Imprint the glowing runes", 3, 1.5),
     op("quench_trough", "Quench in still water", 1), op("grinding_wheel", "Hone", 1)],
    {"ingot_mithril": 2, "leather_cured": 1}, "sword_mithril", 1, DX, {"arcane_metalwork": 80, "smithing": 30},
    requires={"arcane_metalwork": 1}, desc="The magic lives in the metal; the markings glow when the blade is drawn."),
 # ---- iteration 7: jewellery, treatments, leather, the adamantine chain, forgotten and multi-discipline work
 rc("garnet_ring", "Garnet Ring", "classic", "jewellery", "jewel", 3,
    [op("crucible", "Melt the silver", 1), op("anvil", "Draw and close the band", 1, 1.1),
     op("rune_engraving_stand", "Seat the garnet", 1, 1.4), op("rune_polishing_wheel", "Polish band and stone", 1)],
    {"ore_silver": 2, "gem_garnet": 1}, "ring_garnet", 1, DJ, {"smithing": 25, "runecraft": 15}, requires={"smithing": 3},
    desc="Silver set with a garnet; the stone keeps a little of the forge's heat."),
 rc("sapphire_amulet", "Sapphire Amulet", "runecraft", "jewellery", "jewel", 4,
    [op("crucible", "Melt the silver", 1), op("anvil", "Hammer the setting", 1),
     op("rune_cleansing_basin", "Cleanse the sapphire", 1, 0.8), op("rune_engraving_stand", "Bind the stone into the setting", 2, 1.4),
     op("stitching_table", "Braid the cord", 1, 0.5)],
    {"ore_silver": 2, "gem_sapphire": 1, "thread_linen": 1}, "amulet_sapphire", 1, DJ, {"runecraft": 35, "smithing": 10}, requires={"runecraft": 2}),
 rc("frost_coating", "Frost Coating", "alchemy", "alchemy", "herbal", 3,
    [op("mortar_station", "Grind moonwort with quicksalt", 1), op("alembic", "Distil the cold essence", 1, 1.1),
     op("cauldron", "Thicken to a coating", 1, 1.2)],
    {"herb_moonwort": 2, "reagent_salt": 1}, "coating_frost", 1, DP, {"alchemy": 26},
    desc="Brushed onto a blade: rime spreads along the edge on the strike. Apply it at the infusion rack."),
 rc("ranger_boots", "Ranger's Soft Boots", "stitching", "armour", "leather", 2,
    [op("leather_vat", "Soften the uppers", 1, 0.8), op("stitching_table", "Turn-shoe the soles", 2, 1.3)],
    {"leather_cured": 2, "thread_linen": 1}, "boots_ranger", 1, DA, {"enchanted_stitching": 22},
    desc="Light and silent: speed matters more than plate for a scout."),
 rc("embroidered_hood", "Embroidered Hood", "stitching", "armour", "ethereal", 4,
    [op("thread_spinner", "Spin gold-ethereal thread", 1), op("stitching_table", "Cut and stitch the hood", 1),
     op("embroidery_frame", "Embroider warding sigils", 2, 1.4)],
    {"leather_cured": 1, "thread_ethereal": 1}, "hood_embroidered", 1, DA, {"enchanted_stitching": 45}, requires={"enchanted_stitching": 3}),
 rc("emberwarden_longsword", "Emberwarden Longsword", "classic", "weapon", "steel", 5,
    [op("forge", "Bring the steel to yellow heat", 1), op("anvil", "Forge a blade with a socketed guard", 3, 1.4),
     op("rune_engraving_stand", "Seat the ember rune in the guard", 1, 1.3), op("cauldron", "Quench the edge in flame coating", 1, 1.2),
     op("grinding_wheel", "Hone the burning edge", 1, 1.1), op("stitching_table", "Wrap the grip in ghost-thread", 1, 0.6)],
    {"ingot_steel": 2, "runestone_ember": 1, "coating_flame": 1, "thread_ethereal": 1}, "sword_emberwarden", 1, DE,
    {"smithing": 60, "runecraft": 25, "alchemy": 15, "enchanted_stitching": 10}, requires={"smithing": 4, "runecraft": 1},
    desc="Four crafts in one blade: steel, an ember rune, a flame-quenched edge and a ghost-thread grip."),
 rc("starsteel_blade", "Starsteel Blade", "classic", "weapon", "starmetal", 6,
    [op("crucible", "Fuse starmetal into the steel", 2, 1.2), op("forge", "Hold the strange heat", 1),
     op("anvil", "Fold the star-steel", 3, 1.5), op("quench_trough", "Quench in still water", 1, 1.1),
     op("grinding_wheel", "Grind the pale edge", 1)],
    {"ingot_steel": 2, "starmetal_fragment": 1}, "sword_starsteel", 1, DW, {"smithing": 70}, requires={"smithing": 4},
    desc="From a forgotten recipe found among the barrow-relics.", flag="recipe_starsteel"),
 rc("charge_adamantine", "Charge Adamantine", "arcane", "material", "ore", 5,
    [op("arcane_crucible", "Melt adamantine in warded fire", 2), op("leyline_conductor", "Draw the leyline", 1),
     op("aetheric_stabilizer", "Stabilise the bound ward", 1, 1.2)],
    {"ore_adamantine": 2, "gem_moonstone": 1, "coal": 2}, "ingot_adamantine", 1, DM, {"arcane_metalwork": 50, "mining": 40}),
 rc("adamantine_warplate", "Adamantine Warplate", "arcane", "armour", "adamantine", 7,
    [op("forge", "Heat the charged plates", 1), op("arcane_crucible", "Re-melt the ward seams", 1),
     op("arcane_anvil", "Imprint the ward into the plate", 3, 1.5), op("spellbinding_array", "Bind the ward pattern", 2, 1.3),
     op("aetheric_stabilizer", "Settle the bound magic", 1), op("stitching_table", "Rivet the straps", 1, 0.5)],
    {"ingot_adamantine": 2, "leather_cured": 1}, "warplate_adamantine", 1, DXA, {"arcane_metalwork": 90, "smithing": 30},
    requires={"arcane_metalwork": 1}, desc="The ward is in the metal itself — not a rune set into it."),
 # ---- the living village: bows for rangers (and anyone who prefers to fight from afar)
 rc("hunting_bow", "Hunting Bow", "stitching", "weapon", "leather", 2,
    [op("leather_vat", "Steam-bend the stave", 1), op("grinding_wheel", "Shape and balance the limbs", 1, 1.2),
     op("stitching_table", "String and wrap the grip", 1, 0.8)],
    {"yew_stave": 1, "thread_linen": 1, "leather_cured": 1}, "bow_hunting", 1, DW, {"enchanted_stitching": 20, "smithing": 8},
    desc="A ranger's first bow. Rangers fight best with one in hand."),
 rc("yew_longbow", "Yew Longbow", "stitching", "weapon", "leather", 4,
    [op("leather_vat", "Steam-bend the long stave", 1, 1.1), op("grinding_wheel", "Tiller the limbs true", 2, 1.4),
     op("thread_spinner", "Spin a ghost-thread string", 1), op("stitching_table", "Wrap the grip and nock", 1, 0.7)],
    {"yew_stave": 2, "thread_ethereal": 1, "leather_cured": 1}, "bow_yew", 1, DW, {"enchanted_stitching": 45, "smithing": 10},
    requires={"enchanted_stitching": 2}, desc="Taller than its archer. Needs a sure hand at the grinding wheel."),
]

# ---- iteration 9: the skill-tree progression (refined exotic materials, steel and mithril plate,
#      original runes, monster leathers, infusions and the legendary dragon-scale armour).
#      Raw exotic materials (bear_pelt, troll_hide, wyvern_hide, dragon_scale, dragon_bone,
#      ore_orichalcum, herb_*, reagent_aether_dust, reagent_wyrm_ash) come from the trade module.
#      Which skill-tree node teaches each recipe lives in make_skilltree.py.
recipes += [
 rc("steel_cuirass", "Steel Cuirass", "classic", "armour", "steel", 5,
    [op("forge", "Heat the steel plates", 1), op("bellows", "Hold the yellow heat", 1, 0.7),
     op("anvil", "Dish and raise the breastplate", 3, 1.4), op("forge", "Re-heat for the backplate", 1, 0.8),
     op("anvil", "Planish and roll the edges", 2, 1.2), op("quench_trough", "Oil-temper the plates", 1, 1.1),
     op("stitching_table", "Rivet the straps", 1, 0.6)],
    {"ingot_steel": 3, "leather_cured": 1}, "cuirass_steel", 1, DA, {"smithing": 60},
    desc="Folded steel plate: lighter than iron and far harder to dent."),
 rc("kite_shield", "Steel Kite Shield", "classic", "armour", "steel", 4,
    [op("forge", "Heat the long plate", 1), op("anvil", "Raise the kite and band the rim", 2, 1.3),
     op("quench_trough", "Harden the rim", 1), op("grinding_wheel", "Dress the edges", 1)],
    {"ingot_steel": 2, "leather_cured": 1}, "shield_kite", 1, DA, {"smithing": 45},
    desc="A rider's shield; the hardened rim turns a falling blade."),
 rc("smelt_orichalcum", "Smelt Orichalcum", "arcane", "material", "ore", 5,
    [op("arcane_crucible", "Melt orichalcum with aether dust", 2, 1.2), op("bellows", "Drive the heat white", 1, 0.7),
     op("aetheric_stabilizer", "Settle the singing alloy", 1)],
    {"ore_orichalcum": 2, "reagent_aether_dust": 1, "coal": 2}, "ingot_orichalcum", 1, DM, {"arcane_metalwork": 50, "mining": 45},
    desc="The red-gold metal of the old sea-kings, made workable only in warded fire."),
 rc("restore_runestone", "Restore an Old Runestone", "runecraft", "runestone", "runestone", 1,
    [op("rune_cleansing_basin", "Soak away the grave-crust", 1), op("rune_polishing_wheel", "Polish the old face back", 1)],
    {"relic_unknown_tablet": 1}, "runestone_blank", 2, DM, {"runecraft": 45, "relic_hunting": 10},
    desc="Cleaning a weathered tablet yields two sound blanks — and teaches how the old runes were built.",
    teaches="rune_knowledge"),
 rc("frost_runestone", "Frost Runestone", "runecraft", "runestone", "runestone", 3,
    [op("rune_cutting_bench", "Cleave the blank", 1), op("rune_engraving_stand", "Engrave the frost rune", 2, 1.4),
     op("rune_cleansing_basin", "Wash in snowmelt", 1, 0.8), op("resonance_pedestal", "Tune the hum", 2, 1.2)],
    {"runestone_blank": 1, "herb_moonwort": 1}, "runestone_frost", 1, DR, {"runecraft": 35}),
 rc("original_runestone", "Original Rune (your own design)", "runecraft", "runestone", "runestone", 5,
    [op("rune_cutting_bench", "Cleave a flawless blank", 1), op("rune_engraving_stand", "Engrave a rune of your own design", 3, 1.5),
     op("rune_cleansing_basin", "Wash away the chaos", 1, 0.8), op("resonance_pedestal", "Find the note no one has sung", 2, 1.3),
     op("rune_polishing_wheel", "Polish to a mirror", 1)],
    {"runestone_blank": 1, "gem_moonstone": 1}, "runestone_original", 1, DR, {"runecraft": 70},
    desc="Not copied from any tablet: a rune the smith designs, the first of its kind."),
 rc("concord_runestone", "Concord Runestone", "runecraft", "runestone", "runestone", 6,
    [op("rune_engraving_stand", "Interlace three rune patterns", 3, 1.5), op("rune_cleansing_basin", "Wash out the clash", 1, 0.8),
     op("resonance_pedestal", "Tune three runes to one chord", 3, 1.4)],
    {"runestone_original": 1, "runestone_ember": 1, "runestone_ward": 1}, "runestone_concord", 1, DR, {"runecraft": 100},
    desc="A complex combination: fire, ward and your own rune singing as one."),
 rc("mithril_plated_cuirass", "Mithril-plated Cuirass", "arcane", "armour", "mithril", 7,
    [op("forge", "Heat the steel under-plate", 1), op("arcane_crucible", "Run the charged mithril into plate", 2, 1.2),
     op("arcane_anvil", "Hammer the mithril onto the cuirass", 3, 1.5), op("aetheric_stabilizer", "Settle the charge", 1),
     op("stitching_table", "Rivet and strap", 1, 0.5)],
    {"ingot_mithril": 2, "ingot_steel": 2, "reagent_quintessence": 1, "leather_cured": 1}, "mithril_plated_cuirass", 1, DXA,
    {"arcane_metalwork": 90, "smithing": 35}, desc="Steel beneath, charged mithril above; the plates hum when struck."),
 rc("cure_bear_leather", "Cure Bear Leather", "stitching", "material", "bearhide", 2,
    [op("leather_vat", "Flesh and soak the pelt", 1), op("leather_vat", "Tan in oak-bark liquor", 1, 1.2)],
    {"bear_pelt": 1, "reagent_salt": 1}, "leather_bear", 2, DM, {"enchanted_stitching": 28}),
 rc("bearhide_brigandine", "Bearhide Brigandine", "stitching", "armour", "bearhide", 4,
    [op("leather_vat", "Harden the bear leather", 1, 0.8), op("anvil", "Punch the iron plates", 2, 1.1),
     op("stitching_table", "Rivet the plates beneath the leather", 2, 1.3), op("fitting_mannequin", "Fit and balance", 1)],
    {"leather_bear": 3, "ingot_iron": 2, "thread_linen": 1}, "bearhide_brigandine", 1, DA, {"enchanted_stitching": 55, "smithing": 15},
    desc="Thick bear leather over hidden iron plates: a hunter's armour."),
 rc("cure_troll_leather", "Cure Troll Hide", "stitching", "material", "wyrmhide", 4,
    [op("leather_vat", "Burn out the troll-rot", 1, 1.1), op("leather_vat", "Tan with quicksalt", 1, 1.2)],
    {"troll_hide": 1, "reagent_salt": 2}, "leather_wyrm", 1, DM, {"enchanted_stitching": 40}),
 rc("cure_wyvern_leather", "Cure Wyvern Hide", "stitching", "material", "wyrmhide", 5,
    [op("leather_vat", "Scrape the venom glands clean", 1, 1.1), op("leather_vat", "Tan with quicksalt", 2, 1.2)],
    {"wyvern_hide": 1, "reagent_salt": 1}, "leather_wyrm", 2, DM, {"enchanted_stitching": 50}),
 rc("wyrmleather_boots", "Wyrmleather Boots", "stitching", "armour", "wyrmhide", 5,
    [op("leather_vat", "Steam-shape the wyrm leather", 1), op("stitching_table", "Stitch with ghost-thread", 2, 1.3),
     op("embroidery_frame", "Embroider heat-wards", 1, 1.2), op("fitting_mannequin", "Fit to the stride", 1)],
    {"leather_wyrm": 2, "thread_ethereal": 1}, "boots_wyrmleather", 1, DA, {"enchanted_stitching": 70},
    desc="Monster leather that shrugs off fire and never wears through."),
 rc("distil_quintessence", "Silverleaf Quintessence", "alchemy", "material", "herbal", 4,
    [op("mortar_station", "Bruise the silverleaf", 1), op("alembic", "Distil the silver spirit", 2, 1.2),
     op("reagent_table", "Separate the quintessence", 1, 1.1)],
    {"herb_silverleaf": 2, "reagent_salt": 1}, "reagent_quintessence", 1, DM, {"alchemy": 40},
    desc="An advanced reagent: binds charged metal to plain steel."),
 rc("aether_infusion", "Aether Infusion", "alchemy", "alchemy", "herbal", 5,
    [op("alembic", "Distil the frostcap essence", 1), op("cauldron", "Stir in the aether dust", 2, 1.3),
     op("infusion_rack", "Steep under moonlight", 1)],
    {"reagent_aether_dust": 1, "herb_frostcap": 1}, "infusion_aether", 1, DP, {"alchemy": 55},
    desc="A magical infusion: brushed onto equipment at the infusion rack, it lends magic for three expeditions."),
 rc("wyrmfire_coating", "Wyrmfire Coating", "alchemy", "alchemy", "herbal", 6,
    [op("mortar_station", "Grind bloodroot with wyrm ash", 1), op("reagent_table", "Draw off the fire oil", 1, 1.2),
     op("cauldron", "Reduce to a coating", 2, 1.3)],
    {"reagent_wyrm_ash": 1, "herb_bloodroot": 2}, "coating_wyrmfire", 1, DP, {"alchemy": 70},
    desc="An exotic compound: a blade brushed with it burns like dragon's breath."),
 rc("dragonscale_armor", "Dragonscale Armour", "arcane", "armour", "dragonscale", 5,
    [op("forge", "Heat the dragon-bone frame", 1), op("leather_vat", "Prepare the scales in wyrm-ash brine", 2, 1.2),
     op("arcane_anvil", "Set and imprint every scale", 4, 1.6), op("spellbinding_array", "Bind the dragon's fire-ward", 2, 1.3),
     op("stitching_table", "Lace the scales onto wyrm leather", 2, 1.2), op("fitting_mannequin", "Fit the legendary harness", 1)],
    {"dragon_scale": 4, "dragon_bone": 2, "leather_wyrm": 2, "ingot_orichalcum": 1}, "dragonscale_armor", 1, DXA,
    {"arcane_metalwork": 160, "smithing": 60, "enchanted_stitching": 60},
    desc="Legendary armour of true dragon scale on a dragon-bone frame. It never leaves the forge below rare.",
    min_rarity="rare"),
]

if __name__ == "__main__":
    ids = set()
    for r in recipes:
        assert r["id"] not in ids, r["id"]
        ids.add(r["id"])
        for d in r["dice"]:
            assert d in crafting["dice"], (r["id"], d)
        assert r["material"] in crafting["materials"], r["id"]
    W("recipes.json", recipes)
    W("crafting.json", crafting)
    print("recipes.json: %d recipes; crafting.json written" % len(recipes))
