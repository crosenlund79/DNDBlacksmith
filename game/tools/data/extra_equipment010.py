"""Iteration 010 (crafting): Textile & Tailoring materials and garments, and a wider range of weapons, armour and bows.

Fibres come from real sources: flax and wool fleece from the village suppliers (trade runs), the herbalist (flax) and
expedition loot; raw silk from the southern spice traders and special imports; giant spider silk from the spider
nests of Ironroot (mine loot) and as a rare import. Recipes live in make_recipes.py (section "iteration 010"),
the nodes that teach them in make_skilltree.py, icons in tools/art/make_icons.py.

Tags for other systems: every garment carries "cloth"; robes also "robe", cloaks "cloak", padded armour "padded";
magical cloth "enchanted". Two-handed weapons carry "two_handed"; heavy armour "heavy" (its weight is expressed as a
lower speed than lighter pieces — crafted stats never go negative). Cloaks have their own "cloak" slot (worn over the
shoulders, so a cloak and an amulet are worn together); robes, tunics and gambesons the "armor" slot.
"""
from make_data_helpers import it

ITEMS = [
    # ------------------------------------------------------------ raw fibres
    it("flax_bundle", "Flax", "material", None, 3, stack=True, tags=["fibre"],
       desc="Retted flax stalks from Jory's fields: combed, spun and woven they become linen. The seed heads give linseed oil."),
    it("wool_fleece", "Wool Fleece", "material", None, 4, stack=True, tags=["fibre"],
       desc="A greasy fleece off a Brindlewick sheep. Carded and spun it becomes yarn; fulled, it becomes felt."),
    it("silk_raw", "Raw Silk", "material", None, 22, stack=True, tags=["fibre"],
       desc="Hanks of reeled southern silk, gold-white and cool. The spice traders sell it by the ounce."),
    it("spider_silk", "Giant Spider Silk", "material", None, 45, stack=True, tags=["fibre", "rare"],
       desc="Grey strands torn from a cave spider's nest. Stronger than wire once the glue is boiled out — and it drinks shadow."),
    # ------------------------------------------------------------ processed textiles
    it("yarn_wool", "Wool Yarn", "material", None, 7, stack=True, tags=["textile"],
       desc="Hand-spun woollen yarn, ready for the loom."),
    it("cloth_linen", "Linen Cloth", "material", None, 12, stack=True, tags=["textile"],
       desc="A bolt of plain-woven linen: cool, strong and easy to stitch."),
    it("cloth_wool", "Woollen Cloth", "material", None, 14, stack=True, tags=["textile"],
       desc="Twill-woven wool: warm, and it sheds the rain."),
    it("felt_wool", "Felted Wool", "material", None, 13, stack=True, tags=["textile"],
       desc="Fleece fulled in hot water and soap until it mats into thick, wind-proof felt."),
    it("cloth_silk", "Silk Cloth", "material", None, 48, stack=True, tags=["textile"],
       desc="Light, smooth silk. Enchantments sit in it better than in any plant fibre."),
    it("canvas_oiled", "Oiled Canvas", "material", None, 30, stack=True, tags=["textile"],
       desc="Heavy linen rubbed with linseed oil until it turns the rain."),
    it("padding_quilted", "Quilted Padding", "material", None, 32, stack=True, tags=["textile"],
       desc="Layers of linen quilted around carded wool: the heart of a gambeson."),
    # ------------------------------------------------------------ magical textiles
    it("cloth_ethereal", "Ethereal-thread Cloth", "material", None, 70, stack=True, tags=["textile", "enchanted"],
       desc="Wool shot through with ethereal thread; it shimmers faintly when spells are near."),
    it("cloth_moonweave", "Moonweave", "material", None, 120, stack=True, tags=["textile", "enchanted"],
       desc="Silk spun with ethereal thread and moonwort sap, woven by moonlight. It stores magic the way wool stores warmth."),
    it("cloth_spidersilk", "Spidersilk Cloth", "material", None, 110, stack=True, tags=["textile", "enchanted"],
       desc="Grey-black cloth woven from boiled spider silk: light as smoke, hard to cut, hard to see."),
    it("cloth_warded", "Warded Cloth", "material", None, 230, stack=True, tags=["textile", "enchanted", "rare"],
       desc="Moonweave embroidered with a ward rune's pattern and set with aether dust. Curses slide off it."),

    # ------------------------------------------------------------ tailored garments (cloth)
    it("tunic_linen", "Linen Tunic", "armor_cloth", "armor", 22, {"protection": [2, 3], "durability": 40, "speed": 3},
       desc="A plain linen tunic. Nothing to stop a blade — but light enough to run in.", tags=["cloth"]),
    it("gambeson", "Quilted Gambeson", "armor_cloth", "armor", 85, {"protection": [6, 9], "durability": 75, "frost": 1},
       desc="A thick quilted coat: soaks up blows, keeps out the cold, and sits under mail or alone.", tags=["cloth", "padded"]),
    it("robe_novice", "Novice's Robe", "armor_cloth", "armor", 45, {"protection": [1, 3], "durability": 35, "magic": 3},
       desc="Plain wool robes of a hedge-mage's apprentice. Loose sleeves, deep pockets for chalk.", tags=["cloth", "robe"]),
    it("robe_scholar", "Scholar's Robe", "armor_cloth", "armor", 170, {"protection": [2, 4], "durability": 50, "magic": 6, "ward": 2},
       desc="Ethereal-thread cloth dyed moonwort-blue; the hems remember the spells cast in it.", tags=["cloth", "robe", "enchanted"]),
    it("robe_archmage", "Archmage's Robe", "armor_cloth", "armor", 760,
       {"protection": [4, 7], "durability": 85, "magic": 12, "ward": 6, "fire": 3, "frost": 3},
       desc="Warded cloth over moonweave, the sigils embroidered in ghost-thread. It hums like a struck bell when magic passes.",
       tags=["cloth", "robe", "enchanted"]),
    it("cloak_travel", "Travel Cloak", "cloak", "cloak", 55, {"protection": [1, 2], "durability": 55, "frost": 2},
       desc="Oiled canvas over felted wool, clasped at the throat. Rain runs off it; wind does not get through.", tags=["cloth", "cloak"]),
    it("cloak_warded", "Warded Cloak", "cloak", "cloak", 260, {"protection": [1, 3], "durability": 60, "ward": 5, "magic": 3, "frost": 2},
       desc="Ethereal-thread cloth embroidered with ward sigils from hem to hood.", tags=["cloth", "cloak", "enchanted"]),
    it("cloak_shadow", "Shadow Cloak", "cloak", "cloak", 340, {"protection": [2, 3], "durability": 70, "speed": 6, "magic": 4, "ward": 2},
       desc="Spidersilk and moonweave: it drinks lamplight, and the wearer moves like a rumour.", tags=["cloth", "cloak", "enchanted"]),
    it("hood_wool", "Felted Hood", "helmet", "helmet", 18, {"protection": [1, 2], "durability": 35, "frost": 2},
       desc="A thick felt hood and shoulder cape against the northern wind.", tags=["cloth"]),
    it("hood_moonweave", "Moonweave Cowl", "helmet", "helmet", 230, {"protection": [1, 3], "durability": 45, "magic": 5, "ward": 3},
       desc="A deep cowl of moonweave; thoughts come clearer in its shadow.", tags=["cloth", "enchanted"]),
    it("sash_silk", "Silk Sash", "belt", "belt", 90, {"protection": [0, 1], "durability": 40, "magic": 3, "speed": 2},
       desc="A long silk sash, knotted the way the southern spell-dancers knot theirs.", tags=["cloth"]),
    it("gloves_spellweaver", "Spellweaver's Gloves", "gloves", "gloves", 200, {"protection": [1, 2], "durability": 45, "magic": 5, "fire": 2},
       desc="Fingerless silk gloves, the palms stitched with ghost-thread channels for the casting hand.", tags=["cloth", "enchanted"]),

    # ------------------------------------------------------------ swords
    it("sword_short", "Shortsword", "weapon", "weapon", 45, {"attack": [6, 10], "durability": 50, "speed": 5},
       desc="A short, broad blade: quick in a crowded tunnel. Forged in iron or, by a steelworker, in steel."),
    it("sword_cutlass", "Steel Cutlass", "weapon", "weapon", 115, {"attack": [10, 14], "durability": 70, "speed": 3},
       desc="A curved, single-edged sailor's blade with a basket guard. Forgiving and fast."),
    it("sword_rapier", "Steel Rapier", "weapon", "weapon", 180, {"attack": [9, 13], "durability": 55, "speed": 9},
       desc="A long, narrow thrusting blade, spring-tempered so it flexes and never takes a set. Lightning in a duellist's hand."),
    it("sword_great", "Steel Greatsword", "weapon", "weapon", 330, {"attack": [20, 28], "durability": 130},
       desc="A two-handed blade as tall as its bearer. Slow to swing; nothing in its arc stays standing.", tags=["two_handed"]),
    # ------------------------------------------------------------ axes and hammers
    it("axe_hatchet", "Hatchet", "weapon", "weapon", 28, {"attack": [6, 9], "durability": 45, "speed": 3},
       desc="A small iron axe for kindling — and, in a pinch, for goblins."),
    it("axe_battle", "Steel Battle Axe", "weapon", "weapon", 175, {"attack": [14, 19], "durability": 95},
       desc="A broad bearded steel head on an ash haft."),
    it("axe_great", "Steel Great Axe", "weapon", "weapon", 340, {"attack": [21, 29], "durability": 125},
       desc="A double-bitted two-handed axe. A barbarian's idea of an argument.", tags=["two_handed"]),
    it("hammer_war", "Steel Warhammer", "weapon", "weapon", 215, {"attack": [15, 21], "durability": 115},
       desc="A spiked steel hammer that crumples plate and cracks bone through mail."),
    # ------------------------------------------------------------ armour
    it("armor_hide", "Hide Armour", "armor_leather", "armor", 38, {"protection": [4, 6], "durability": 55},
       desc="Stiff, half-cured hide laced into a coat. Crude, warm and cheap."),
    it("armor_studded", "Studded Leather", "armor_leather", "armor", 95, {"protection": [7, 10], "durability": 80, "speed": 2},
       desc="Boiled leather set with iron studs: real protection without the weight of mail."),
    it("plate_half", "Steel Half-Plate", "armor_metal", "armor", 430, {"protection": [16, 21], "durability": 165},
       desc="Breastplate, pauldrons and tassets over mail. Heavy — but a blade skates off it.", tags=["heavy"]),
    it("plate_full", "Full Plate Harness", "armor_metal", "armor", 680, {"protection": [19, 26], "durability": 210},
       desc="A complete articulated harness of folded steel, every lame fitted to its wearer. The heaviest, surest armour a smith can make.",
       tags=["heavy"]),
    # ------------------------------------------------------------ shields
    it("shield_buckler", "Buckler", "shield", "shield", 28, {"protection": [2, 4], "durability": 50, "speed": 2},
       desc="A fist-sized iron boss on a leather-lined dish. Parries more than it blocks."),
    it("shield_tower", "Steel Tower Shield", "shield", "shield", 190, {"protection": [9, 14], "durability": 140},
       desc="A tall steel-faced shield that covers a man from chin to shin.", tags=["heavy"]),
    # ------------------------------------------------------------ bows
    it("bow_short", "Shortbow", "weapon", "weapon", 40, {"attack": [5, 8], "durability": 45, "speed": 6},
       desc="A short ash bow: easy to draw, quick to shoot, short in reach."),
    it("bow_recurve", "Recurve Bow", "weapon", "weapon", 240, {"attack": [12, 17], "durability": 85, "speed": 7},
       desc="Steam-bent tips curl away from the archer; bear sinew on the back. Hits like a longbow from a shorter stave."),
    it("bow_warbow", "Silverleaf Warbow", "weapon", "weapon", 400, {"attack": [15, 21], "durability": 100, "speed": 6, "magic": 3},
       desc="An elven-style warbow of yew varnished with silverleaf quintessence and strung with ghost-thread; it sings when loosed.",
       tags=["enchanted"]),
]
