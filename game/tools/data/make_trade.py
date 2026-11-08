"""Generates game/data/trade.json — the herbalist's stock, the merchant ships that call at Brindlewick
harbour and the harbourmaster's catalogue of special imports.  Read in game with DB.extra("trade").
Run: python3 tools/data/make_trade.py   (make_data.py also writes it through extra_trade.py)

herbalist.stock: [item, base price, [min, max] daily quantity] — prices x Expeditions.diff().prices.
ships.<type>.stock: [item, price multiplier on the item's value, [min, max] qty, chance to be aboard].
ships.<type>.equipment: [item, price multiplier, chance] — a single finished piece each.
imports: item -> {tier, lead: [min, max] days, mult}; price = value x mult x difficulty; deposit share up front.
"""
import json
import os

D = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "data")

HERBALIST = {
    "id": "herbalist",
    "shop": "Fennimore's Simples",
    "stock": [
        ["herb_emberleaf", 8, [4, 8]], ["herb_moonwort", 8, [4, 8]], ["reagent_salt", 6, [3, 6]],
        ["herb_bloodroot", 11, [3, 6]], ["herb_frostcap", 12, [2, 5]], ["herb_silverleaf", 16, [2, 4]],
        ["yew_stave", 17, [1, 3]], ["reagent_aether_dust", 78, [1, 2]],
        ["flax_bundle", 4, [3, 8]],
    ],
    "lines": [
        "\"Bloodroot for the bleeding, frostcap for the fever, and silverleaf when neither works.\"",
        "\"Aether dust? Scraped off the old waystones by moonlight. That's why it costs what it costs.\"",
        "\"Mind the jars on the left — those are for customers I like.\"",
        "\"Your forge smoke turns my moonwort bitter, smith. I'll forgive it if you buy the bitter ones.\"",
        "\"Everything fresh this morning. Well — fresh this week.\"",
    ],
}

SHIPS = {
    "spice": {
        "label": "Southern spice trader", "sprite": "props/ship_spice",
        "names": [["The Gilded Heron", "Captain Idris Sallah"], ["The Saffron Moon", "Captain Nadira Vell"], ["The Amber Lantern", "Captain Oren Kassim"]],
        "desc": "Out of the southern ports with reagents, rare herbs and fine thread.",
        "stock": [
            ["reagent_aether_dust", 1.5, [2, 5], 1.0], ["reagent_wyrm_ash", 1.6, [1, 3], 0.7], ["herb_silverleaf", 1.3, [4, 8], 0.9],
            ["herb_frostcap", 1.3, [3, 6], 0.7], ["herb_bloodroot", 1.3, [4, 8], 0.7], ["reagent_salt", 1.2, [6, 10], 0.8],
            ["thread_ethereal", 1.5, [2, 4], 0.6], ["silk_raw", 1.4, [2, 6], 0.8], ["gem_sapphire", 1.4, [1, 2], 0.5], ["gem_garnet", 1.4, [1, 3], 0.5],
        ],
        "equipment": [["amulet_silver", 1.6, 0.4], ["ring_silver", 1.6, 0.4], ["coating_flame", 1.4, 0.4]],
        "ironfront_chance": 0.35,
    },
    "barge": {
        "label": "Dwarven ore barge", "sprite": "props/ship_barge",
        "names": [["The Stubborn Anvil", "Skipper Durra Coalbrow"], ["The Iron Wife", "Skipper Haldor Grimm"], ["The Deep Delver", "Skipper Thrain Ashdeep"]],
        "desc": "Broad-bellied and low in the water: ore, ingots and the odd dwarf-made piece.",
        "stock": [
            ["ore_orichalcum", 1.6, [1, 3], 0.8], ["ore_mithril", 1.4, [2, 4], 0.9], ["ore_adamantine", 1.5, [1, 3], 0.7],
            ["ingot_steel", 1.3, [4, 8], 1.0], ["ore_silver", 1.3, [3, 6], 0.8], ["gem_starstone", 1.7, [1, 1], 0.25],
            ["runestone_blank", 1.4, [2, 4], 0.6], ["coal", 1.5, [10, 20], 0.6],
        ],
        "equipment": [["sword_bastard", 1.5, 0.4], ["shield_kite", 1.5, 0.4], ["helm_iron", 1.5, 0.4], ["cuirass_iron", 1.5, 0.3]],
        "ironfront_chance": 0.25,
    },
    "whaler": {
        "label": "Far-north whaler", "sprite": "props/ship_whaler",
        "names": [["The Grey Widow", "Captain Ottar Hrafnsson"], ["The Ice Lark", "Captain Sigga Ulfsdottir"], ["The Long Winter", "Captain Bram Kold"]],
        "desc": "Tarred black and smelling of oil: furs, monster hides and things from the ice.",
        "stock": [
            ["bear_pelt", 1.4, [2, 4], 0.9], ["troll_hide", 1.5, [1, 3], 0.8], ["wyvern_hide", 1.6, [1, 2], 0.6],
            ["leather_cured", 1.3, [4, 8], 0.8], ["leather_hide", 1.3, [6, 10], 0.8], ["herb_frostcap", 1.3, [4, 8], 0.6],
            ["dragon_scale", 2.0, [1, 1], 0.12], ["dragon_bone", 2.0, [1, 1], 0.08],
        ],
        "equipment": [["boots_ranger", 1.5, 0.4], ["bow_yew", 1.5, 0.3], ["jerkin_leather", 1.5, 0.4]],
        "ironfront_chance": 0.3,
    },
}

SCHEDULE = {"gap": [3, 6], "stay": 2, "arrive_hour": 7, "first_after_days": 2}

IMPORT_TIERS = {
    "common": {"lead": [2, 3], "mult": 1.6},
    "rare": {"lead": [4, 6], "mult": 1.8},
    "exotic": {"lead": [6, 8], "mult": 2.0},
    "legendary": {"lead": [9, 12], "mult": 2.4},
}
_IMPORT_LIST = {
    "common": ["ingot_steel", "ore_silver", "leather_cured", "thread_ethereal", "herb_bloodroot", "herb_frostcap", "herb_silverleaf",
               "herb_emberleaf", "herb_moonwort", "reagent_salt", "yew_stave", "gem_garnet", "gem_sapphire", "gem_moonstone", "bear_pelt",
               "silk_raw", "wool_fleece", "flax_bundle"],
    "rare": ["ore_mithril", "ore_adamantine", "reagent_aether_dust", "troll_hide", "runestone_blank", "spider_silk"],
    "exotic": ["ore_orichalcum", "wyvern_hide", "reagent_wyrm_ash", "gem_starstone"],
    "legendary": ["dragon_scale", "dragon_bone"],
}
IMPORTS = {d: {"tier": t, **{k: v for k, v in IMPORT_TIERS[t].items()}} for t, ids in _IMPORT_LIST.items() for d in ids}

HARBOUR = {
    "id": "harbourmaster",
    "deposit": 0.4,
    "max_open": 4,
    "lines": [
        "\"Tide's right, the wind's from the south. Something will come in.\"",
        "\"Write it in the book, pay the deposit, and I'll pass the word to the next captain out.\"",
        "\"Dragon scale? Aye, it can be had. It's the getting it here alive that costs.\"",
    ],
}


## Pell's Provisions (Aldric Pell) — the village general store: the everyday workshop basics a smith runs short of
## (iteration UX: iron ore and coal had no shop at all). Same shape as the herbalist; a little dearer than a trade
## run, restocked each morning in small lots, so expeditions, mining and trade runs stay worth doing.
GENERAL_STORE = {
    "id": "general_store",
    "shop": "Pell's Provisions",
    "keeper": "aldric",
    "stock": [
        ["ore_iron", 8, [6, 12]], ["coal", 4, [8, 16]], ["leather_hide", 8, [3, 6]], ["leather_cured", 19, [1, 3]],
        ["thread_linen", 5, [3, 6]], ["wool_fleece", 6, [2, 4]],
    ],
    "lines": [
        "\"Ore from the Ironroot carters, coal by the sack, hides from the tanner's cart. Mind the lamp oil.\"",
        "\"Cured leather's dear this week — the tanner's lad broke his arm.\"",
        "\"Bread's for your belly, smith, the iron's for your forge. Don't mix them up.\"",
        "\"If you want ore by the cartload, send someone up the Highmarsh road. I sell it by the basket.\"",
    ],
}


def data():
    return {"herbalist": HERBALIST, "general_store": GENERAL_STORE, "ships": SHIPS, "schedule": SCHEDULE, "imports": IMPORTS, "harbour": HARBOUR}


def write():
    with open(os.path.join(D, "trade.json"), "w") as f:
        json.dump(data(), f, indent=1, ensure_ascii=False)
    print("trade.json:", len(SHIPS), "ship types,", len(IMPORTS), "importables")


if __name__ == "__main__":
    write()
