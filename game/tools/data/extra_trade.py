"""Trade content: exotic crafting materials, the herbalist and the harbourmaster, docked-ship props.
Imported by make_data.py (ITEMS, CHARACTERS, PROPS). Importing this module also regenerates
data/trade.json (herbalist stock, ship types, import catalogue) through make_trade.write().

Fixed ids used by other systems (do not rename): bear_pelt, troll_hide, wyvern_hide, dragon_scale,
dragon_bone, ore_orichalcum, herb_bloodroot, herb_frostcap, herb_silverleaf, reagent_aether_dust,
reagent_wyrm_ash; characters herbalist, harbourmaster.
"""
from make_data_helpers import it, ch, L, P

ITEMS = [
    # hides
    it("bear_pelt", "Bear Pelt", "material", None, 32, stack=True, tags=["hide", "exotic"],
       desc="A raw Whisperwood bear pelt, thick-furred and heavy. Tanned and cured it becomes bear leather."),
    it("troll_hide", "Troll Hide", "material", None, 72, stack=True, tags=["hide", "rare", "exotic"],
       desc="Grey-green, knobbled and still faintly warm. It knits itself shut where it is cut — slowly."),
    it("wyvern_hide", "Wyvern Hide", "material", None, 140, stack=True, tags=["hide", "rare", "exotic"],
       desc="Scaled hide from a wyvern's flank: light, tough and stubborn about catching fire."),
    # dragon parts
    it("dragon_scale", "Dragon Scale", "material", None, 620, stack=True, tags=["rare", "exotic", "dragon"],
       desc="A single scale the size of a palm, black-red and warm to the touch. Nothing in Brindlewick can cut it cold."),
    it("dragon_bone", "Dragon Bone", "material", None, 520, stack=True, tags=["rare", "exotic", "dragon"],
       desc="A length of dragon bone, hollow and lighter than oak, harder than good steel."),
    # exotic ore
    it("ore_orichalcum", "Orichalcum Ore", "material", None, 165, stack=True, tags=["rare", "exotic"],
       desc="Red-gold ore that rings like a bell when struck. The dwarves of the deep halls prized it above mithril."),
    # common alchemy herbs
    it("herb_bloodroot", "Bloodroot", "material", None, 8, stack=True, tags=["herb"],
       desc="A knotted red root; its sap stops bleeding and stings like nettles."),
    it("herb_frostcap", "Frostcap", "material", None, 9, stack=True, tags=["herb"],
       desc="A pale mushroom that grows where the frost stays longest. Cold to hold, even in summer."),
    it("herb_silverleaf", "Silverleaf", "material", None, 12, stack=True, tags=["herb"],
       desc="Narrow leaves with a silver underside; steeped, they calm a fever and clear a fouled wound."),
    # magical reagents
    it("reagent_aether_dust", "Aether Dust", "material", None, 48, stack=True, tags=["reagent", "rare"],
       desc="Glittering blue-violet dust scraped from leyline stones. Binds magic to metal and cloth."),
    it("reagent_wyrm_ash", "Wyrm Ash", "material", None, 95, stack=True, tags=["reagent", "rare", "exotic"],
       desc="Ash from a wyrm's pyre, still glowing at its heart. A pinch in the quench makes steel remember fire."),
]

CHARACTERS = [
    ch("herbalist", "Maud Fennimore", "villager",
       L(build="slim", female=True, skin="#e2c0a0", hair="bun", hair_col="#c8c4b8", beard="none", armor="robe",
         shirt="#5e6e4a", cloak="#4e5a3a", back="none", hand="basket", extras=[]),
       age=63, title="Herbalist", work="herbalist",
       personality="Brisk and kindly; names every plant in Old Speech and every customer by their ailments."),
    ch("harbourmaster", "Captain Hal Brackwater", "villager",
       L(build="heavy", female=False, skin="#c48a66", hair="short", hair_col="#6a6058", beard="short", beard_col="#8a8076",
         armor="leather", shirt="#3e4a6e", cloak="#2e3450", back="none", hand="none", extras=["eyepatch"]),
       age=57, title="Harbourmaster", work="harbour",
       personality="Salt-cured and unhurried; knows every ship by her creak and every captain by his debts."),
]

PROPS = {
    "ship_spice": P(512, 192, desc="moored southern spice trader seen from above: lateen sails furled, crates of spice on deck"),
    "ship_barge": P(512, 192, desc="moored dwarven ore barge seen from above: broad flat hull, ore bins, square sail furled"),
    "ship_whaler": P(512, 192, desc="moored far-north whaler seen from above: dark tarred hull, hides drying on deck"),
    "ship_flag": P(48, 96, solid=False, desc="harbour signal pole with a pennant: a ship is expected"),
}

try:
    import make_trade
    make_trade.write()
except Exception as _e:  # never break make_data.py because of the trade catalogue
    print("extra_trade: trade.json not written:", _e)
