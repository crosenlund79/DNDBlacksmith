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
 },
}

# ---------------------------------------------------------------- dice sets
DW = {"edge": "1d20", "temper": "1d12", "fortune": "1d100"}
DA = {"guard": "1d20", "temper": "1d12", "fortune": "1d100"}
DM = {"purity": "1d6"}
DP = {"potency": "1d8", "fortune": "1d100"}
DR = {"resonance": "1d10", "fortune": "1d100"}
DX = {"edge": "1d20", "spellweave": "1d12", "temper": "1d12", "fortune": "1d100"}


def op(station, name, checks=1, weight=1.0):
    return dict(station=station, op=name, checks=checks, weight=weight)


def rc(id, name, disc, category, material, difficulty, ops, inputs, out, qty=1, dice=None, xp=None,
       requires=None, desc=""):
    return dict(id=id, name=name, discipline=disc, category=category, material=material,
                difficulty=difficulty, operations=ops, steps=[o["station"] for o in ops],
                inputs=inputs, output=out, qty=qty, dice=dice or {}, xp=xp or {},
                requires=requires or {}, desc=desc)


recipes = [
 # ---- materials (short: one or two operations)
 rc("smelt_iron", "Smelt Iron Ingots", "classic", "material", "ore", 1,
    [op("crucible", "Melt the ore", 1), op("forge", "Cast and cool the ingots", 1)],
    {"ore_iron": 2, "coal": 1}, "ingot_iron", 2, DM, {"smithing": 12}),
 rc("smelt_steel", "Fold Steel Ingot", "classic", "material", "iron", 3,
    [op("crucible", "Melt iron with carbon", 1), op("bellows", "Drive the heat up", 2, 0.7),
     op("forge", "Fold and weld the bloom", 2, 1.2)],
    {"ingot_iron": 2, "coal": 2}, "ingot_steel", 1, DM, {"smithing": 18}),
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
    {"ore_mithril": 2, "coal": 2}, "ingot_mithril", 1, DM, {"arcane_metalwork": 40}),
 rc("mithril_runeblade", "Mithril Runeblade", "arcane", "weapon", "mithril", 7,
    [op("forge", "Heat the charged billet", 1), op("arcane_crucible", "Re-melt the fuller channel", 1),
     op("spellbinding_array", "Bind the spell pattern", 2, 1.3), op("arcane_anvil", "Imprint the glowing runes", 3, 1.5),
     op("quench_trough", "Quench in still water", 1), op("grinding_wheel", "Hone", 1)],
    {"ingot_mithril": 2, "leather_cured": 1}, "sword_mithril", 1, DX, {"arcane_metalwork": 80, "smithing": 30},
    requires={"arcane_metalwork": 1}, desc="The magic lives in the metal; the markings glow when the blade is drawn."),
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
