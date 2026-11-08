"""Iteration 9 progression content: refined exotic materials and the equipment the skill tree opens up.

Raw exotic materials (bear_pelt, troll_hide, wyvern_hide, dragon_scale, dragon_bone, ore_orichalcum,
herb_bloodroot, herb_frostcap, herb_silverleaf, reagent_aether_dust, reagent_wyrm_ash) are defined by
the trade module (extra_trade.py) — not here. Recipes live in make_recipes.py, the nodes that teach
them in make_skilltree.py, icons in tools/art/make_icons.py.
"""
from make_data_helpers import it

ITEMS = [
    # refined materials
    it("leather_bear", "Bear Leather", "material", None, 30, stack=True,
       desc="Thick, warm leather cured from a bear pelt.", tags=["leather"]),
    it("leather_wyrm", "Wyrm Leather", "material", None, 75, stack=True,
       desc="Troll or wyvern hide tanned until it no longer stinks of the swamp. Fire barely marks it.", tags=["leather", "rare"]),
    it("ingot_orichalcum", "Orichalcum Ingot", "material", None, 240, stack=True,
       desc="Red-gold magical alloy of the old sea-kings, smelted in warded fire.", tags=["arcane", "rare"]),
    it("reagent_quintessence", "Silverleaf Quintessence", "material", None, 45, stack=True,
       desc="An advanced alchemical reagent that binds charged metal to plain steel."),
    # runes
    it("runestone_original", "Smith's Own Rune", "runestone", None, 170, {"magic": 5, "ward": 3}, stack=True,
       desc="A rune of your own design — no tablet ever showed it. Set into equipment it lends magic and a ward."),
    it("runestone_concord", "Concord Runestone", "runestone", None, 280, {"fire": 4, "ward": 4, "magic": 4}, stack=True,
       desc="Three runes tuned to one chord: fire, ward and your own."),
    # alchemy
    it("infusion_aether", "Aether Infusion", "potion", None, 95, {"magic": 3}, stack=True,
       desc="Brushed onto equipment at the infusion rack: it lends magic for three expeditions."),
    it("coating_wyrmfire", "Wyrmfire Coating", "potion", None, 140, {"fire": 4}, stack=True,
       desc="Bloodroot and wyrm ash: a blade brushed with it burns like dragon's breath."),
    # equipment
    it("cuirass_steel", "Steel Cuirass", "armor_metal", "armor", 230, {"protection": [13, 18], "durability": 130},
       desc="Folded steel plate, lighter than iron and harder to dent."),
    it("bearhide_brigandine", "Bearhide Brigandine", "armor_leather", "armor", 160, {"protection": [9, 13], "durability": 100},
       desc="Bear leather over riveted iron plates: a hunter's armour."),
    it("boots_wyrmleather", "Wyrmleather Boots", "boots", "boots", 260, {"protection": [3, 5], "durability": 95, "speed": 4, "fire": 2},
       desc="Monster leather embroidered with heat-wards.", tags=["enchanted"]),
    it("mithril_plated_cuirass", "Mithril-plated Cuirass", "armor_metal", "armor", 580,
       {"protection": [17, 23], "durability": 170, "ward": 4, "magic": 3},
       desc="Charged mithril plates hammered over steel; they hum when struck.", tags=["arcane"]),
    it("dragonscale_armor", "Dragonscale Armour", "armor_metal", "armor", 1800,
       {"protection": [22, 30], "durability": 240, "fire": 8, "ward": 8, "magic": 6},
       desc="True dragon scale on a dragon-bone frame. Legendary-grade armour; few smiths alive could make it.",
       tags=["arcane", "legendary_grade", "dragon"]),
]
