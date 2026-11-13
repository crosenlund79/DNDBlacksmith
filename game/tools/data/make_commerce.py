"""Generates game/data/commerce.json — the travelling caravan, the pawnshop, the rival smith's forge and the Hales'
creature yard. Read in game with DB.extra("commerce") (Commerce.cfg()).
Run: python3 tools/data/make_commerce.py   (make_data.py also writes it through extra_commerce.py)

caravan.stock: [item, price multiplier on the item's value, [min, max] qty, chance to be in the wagons].
caravan.equipment / curiosities: [item, price multiplier, chance] — single pieces.
caravan.wanted: [item, premium multiplier on value] — each visit picks `wanted_count` of them.
pawn: payout / buyback / sale shares of an item's value; hold_days before an unredeemed pledge goes on sale.
rival.stock: [item, price multiplier, chance]; rival.materials: [item, mult, [min, max], chance].
rival.plain (S2): [item, price multiplier, chance, [min, max] craftsmanship] — her plain everyday work, always common, priced
  within a starting adventurer's purse (PROP-015).
creatures.ordinary / magical: [companion item, chance to be in the yard each week].
"""
import json
import os

D = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "data")

CARAVAN = {
    "label": "The Brask Caravan",
    "schedule": {"first_after_days": 5, "gap": [6, 10], "stay": 2, "arrive_hour": 9},
    "desc": "Three painted wagons out of the east: curios, exotic stuff, fine arms and stranger things.",
    "stock": [
        ["thread_ethereal", 1.4, [2, 4], 0.7], ["gem_starstone", 1.35, [1, 1], 0.35], ["gem_moonstone", 1.3, [1, 3], 0.7],
        ["reagent_quintessence", 1.4, [1, 3], 0.6], ["leather_wyrm", 1.35, [1, 2], 0.5], ["starmetal_fragment", 1.4, [1, 2], 0.45],
        ["ore_orichalcum", 2.6, [1, 1], 0.04], ["troll_hide", 1.3, [1, 2], 0.5], ["reagent_wyrm_ash", 1.35, [1, 2], 0.45],
        ["dragon_scale", 1.25, [1, 1], 0.15], ["ingot_mithril", 2.8, [1, 1], 0.03], ["potion_healing", 1.2, [2, 5], 0.8],
    ],
    "equipment": [
        ["bow_yew", 1.35, 0.5], ["boots_ranger", 1.3, 0.55], ["hood_embroidered", 1.3, 0.4], ["amulet_sapphire", 1.35, 0.4],
        ["ring_garnet", 1.35, 0.45], ["gloves_warded", 1.3, 0.35], ["sword_starsteel", 1.4, 0.2], ["bearhide_brigandine", 1.3, 0.35],
    ],
    "curiosities": [
        ["curio_tide_compass", 1.25, 0.6], ["curio_songbird", 1.25, 0.5], ["curio_seer_glass", 1.25, 0.6], ["curio_star_chart", 1.25, 0.5],
        ["relic_unknown_tablet", 1.6, 0.4], ["relic_unknown_reliquary", 1.6, 0.3],
    ],
    "ironfront_chance": 0.5,
    "ironfront_price": 140,
    "wanted_count": 3,
    "wanted": [
        ["ingot_steel", 1.7], ["ingot_iron", 1.8], ["leather_cured", 1.7], ["potion_healing", 1.5], ["oil_whetstone", 1.6],
        ["runestone_ember", 1.5], ["runestone_ward", 1.5], ["herb_emberleaf", 2.0], ["coating_flame", 1.5], ["sword_steel", 1.35],
        ["dagger", 1.5], ["shield_round", 1.5], ["helm_iron", 1.5], ["bear_pelt", 1.5], ["yew_stave", 1.8], ["gem_garnet", 1.4],
    ],
    "wanted_max": 4,
    "lines": [
        "\"Every wagon has a story, smith, and every story has a price. The stories are cheaper.\"",
        "\"From Qasr-by-the-Dunes to your little square — mind the tassels, they are older than you.\"",
        "\"No, the songbird is not haunted. It merely remembers.\"",
        "\"We buy, too! Good steel travels further than gold, and spoils less than bread.\"",
        "\"Two nights, then the road. The road is a jealous wife.\"",
    ],
}

PAWN = {
    "shop": "Quell's Pledges & Loans",
    "payout": 0.40,          # what the smith gets for a pledge, share of value
    "buyback": 0.65,         # what redeeming it costs, share of value
    "sale": 0.85,            # forfeited pledges and the house stock sell at this share of value
    "hold_days": 10,         # how long a pledge is held for the smith before it goes on the shelf
    "max_pledges": 30,
    "forfeit_keep_days": 20, # a forfeited pledge stays on the shelf this long, then is sold to someone else
    "house_stock": [
        ["relic_coin", 0.9, 0.6], ["relic_idol", 0.9, 0.4], ["ring_silver", 0.9, 0.6], ["amulet_silver", 0.9, 0.5],
        ["dagger", 0.9, 0.7], ["sword_iron", 0.9, 0.6], ["shield_round", 0.9, 0.5], ["helm_iron", 0.9, 0.5],
        ["curio_seer_glass", 1.0, 0.3], ["gem_garnet", 0.95, 0.5], ["potion_healing", 0.95, 0.6],
    ],
    "never": ["container", "quest"],
    "lines": [
        "\"A ticket for every pledge, and every pledge in its place. I do not lose things, smith.\"",
        "\"I pay four parts in ten. Come back for it inside ten days and it costs you six and a half.\"",
        "\"Everything has a price. Most things have two.\"",
        "\"I never ask where a thing came from. I only ask whether it will still be a thing tomorrow.\"",
    ],
}

RIVAL = {
    "shop": "The Salt Anvil",
    "restock_days": 4,
    "stock": [
        ["cutlass_seabronze", 1.45, 0.9], ["harpoon_barbed", 1.45, 0.7], ["buckler_seabronze", 1.45, 0.85],
        ["helm_brinecap", 1.45, 0.75], ["sabre_ripple", 1.5, 0.45], ["sword_starsteel", 1.55, 0.25],
        ["boots_ranger", 1.4, 0.5], ["cuirass_steel", 1.45, 0.4], ["bow_yew", 1.45, 0.35],
    ],
    "materials": [
        ["ingot_steel", 1.4, [3, 6], 0.7], ["wyvern_hide", 1.5, [1, 1], 0.2],
        ["ingot_orichalcum", 2.8, [1, 1], 0.03], ["reagent_salt", 1.3, [3, 6], 0.6],
    ],
    # S2: plain everyday work for beginners — iron mail and leather boots, gloves and belts (she already sells boots), the
    # ordinary pieces a new Ironhand forge cannot make yet; ordinary craftsmanship at a small markup. Plain iron weapons,
    # helmets and shields are left to the smith's own work (with them here, more of what adventurers ask the smith for
    # was beyond his forge: 27 % → 30 % of requests over 8 seeds).
    "plain": [
        ["chainmail", 1.15, 0.45, [62, 78]],
        ["boots_leather", 1.2, 0.6, [62, 78]], ["gloves_leather", 1.2, 0.5, [62, 78]], ["belt_leather", 1.2, 0.4, [62, 78]],
    ],
    "adv_chance": 0.5,       # chance an adventurer with gold to spare looks in at the Salt Anvil on a given day
    "lines": {
        "greet": [
            "\"Ha! The competition! Come to see how it's done?\"",
            "\"Mind the quench barrel — it's brine. Everything I make is born in salt.\"",
            "\"Brindlewick smith! Sit, sit. Mind the anchor.\"",
        ],
        "shop": [
            "\"Sea-bronze: copper, tin and a pinch of something I'll take to my grave. It doesn't rust, it doesn't sulk, and it rings like a ship's bell.\"",
            "\"The ripple-steel comes in cakes from the south. Fold it right and the blade shows water. Fold it wrong and you've made a very expensive horseshoe.\"",
            "\"Your iron's honest work. Mine just lasts longer at sea. Different trades, smith — mostly.\"",
            "\"I forged anchors for the fleet at Saltmere for twenty years. After an anchor, a sword is a toothpick.\"",
            "\"Charcoal from driftwood burns blue. Don't ask me why. I asked my mother, and she hit me with a ladle.\"",
        ],
        "rivalry": {
            "low": [
                "\"Your shop? Cute. Like a forge in a teacup. Give it a year.\"",
                "\"Folk still come to me for anything with an edge. No offence. Well — a little offence.\"",
            ],
            "mid": [
                "\"I hear the adventurers talk about your work at the Wyvern. Don't let it go to your head — it barely fits mine.\"",
                "\"Not bad, that last blade of yours. I said not bad. Don't make me say it twice.\"",
            ],
            "high": [
                "\"Fine! Fine. You're the best smith in Brindlewick. I'm the best smith in Brindlewick who isn't you. I'll take that.\"",
                "\"Half my customers ask whether I've seen your work. The other half have seen it. I'm raising my prices out of spite.\"",
            ],
            "hof": [
                "\"Your name on a Hall of Fame board, and mine on a fish-market bench. The sea gods have a sense of humour.\"",
                "\"I walked past that Hall of Fame of yours. I counted the plaques. Twice. I'm not jealous; I'm motivated.\"",
            ],
        },
        "tips": [
            {"text": "\"Want orichalcum? It comes up out of the deep places — the halls under Ironroot, the rifts. Now and then a dwarven barge carries a nugget, at a price to make you weep. Red-gold, rings like a bell; you'll know it.\"", "flag": "heard_ore_orichalcum"},
            {"text": "\"Quench steel in brine, not water — cooler and kinder, fewer cracks. Your skill tree will tell you the same, when you've learned to read it.\"", "flag": ""},
            {"text": "\"Troll hide knits itself if you cut it slow. Cure it in salt first. The caravan from the east sometimes has some.\"", "flag": "heard_troll_hide"},
            {"text": "\"Wyrm ash in the quench makes steel remember fire. The southern spice ships bring it — by the pinch, and by the fortune.\"", "flag": "heard_reagent_wyrm_ash"},
            {"text": "\"If you ever get your hands on mithril, don't hammer it cold — it remembers every blow and holds a grudge. Learn the arcane forge first.\"", "flag": ""},
            {"text": "\"Starmetal falls where the sky is thin. Adventurers find it in the high places and sell it to whoever asks nicely. Ask nicely.\"", "flag": "heard_starmetal_fragment"},
        ],
    },
}

CREATURES = {
    "yard": "Hale Farm — Beasts & Curious Creatures",
    "restock_days": 7,
    "ordinary": [["comp_mouser_cat", 1.0], ["comp_pack_mule", 0.9], ["comp_fell_pony", 0.8], ["comp_war_hound", 0.8], ["comp_hunting_falcon", 0.7]],
    "magical": [["comp_moon_moth", 0.5], ["comp_stone_toad", 0.45], ["comp_glimmer_fox", 0.35], ["comp_pocket_drake", 0.25]],
    "commission": {"lead": [3, 6], "deposit": 0.5, "markup": 1.15},
    "sell_markup": [1.0, 1.15, 1.3],
    "finder_fee": 0.1,
    "names": {
        "cat": ["Thimble", "Soot", "Marrow", "Pewter", "Mistress Whiskers", "Ash", "Pip"],
        "mule": ["Patience", "Old Grumble", "Biscuit", "Saddlebags", "Mortimer", "Clover"],
        "pony": ["Bracken", "Thistle", "Nettle", "Dapple", "Heather", "Tor"],
        "hound": ["Bramble", "Ironjaw", "Hob", "Ruff", "Ember", "Brindle", "Gristle", "Tansy"],
        "falcon": ["Swiftwing", "Kestrel", "Arrow", "Skye", "Talon", "Hob-in-the-Clouds"],
        "moon-moth": ["Lumen", "Silverdust", "Nightlamp", "Wisp", "Hush"],
        "stone-toad": ["Cobble", "Grandmother Granite", "Pebble", "Slate", "Mossback"],
        "glimmer-fox": ["Spark", "Flicker", "Lantern", "Will", "Glint"],
        "drake": ["Cinders", "Smudge", "Kettle", "Flint", "Puddle", "Tinderbox"],
    },
    "lines": {
        "hale_elder": [
            "\"Easy now — let her sniff your hand first. There. Now you're friends.\"",
            "\"A good hound doesn't need to be told twice. A good owner doesn't need to tell it once.\"",
            "\"Mules aren't stubborn, smith. They're careful. There's a difference, and it's usually a cliff.\"",
            "\"Feed 'em before yourself, and they'll walk into a barrow for you. Not that they should.\"",
        ],
        "hale_younger": [
            "\"Oh! Don't — sorry — don't touch the moth, she's moulting. Well, not moulting. Re-dusting. It's in my notes.\"",
            "\"Did you know a glimmer-fox can smell a lie? Not a fib, a proper lie. I'm writing a paper on it.\"",
            "\"The drake's name is Kettle. He chose it. Well — he set fire to everything else I suggested.\"",
            "\"Stone-toads hum in a key you feel in your teeth. That's the magic. Or indigestion. Still researching.\"",
        ],
        "talk_elder": [
            "\"Forty years on this farm. My wife kept the bees, I kept everything else. Now Ellery keeps the things I don't understand.\"",
            "\"An adventurer came back from the Barrow Fields once without his hound. He sat right where you're standing and cried for an hour. I don't sell to fools since.\"",
            "\"The boy went off to the Collegium to learn proper science. Came back with a moth in his pocket. I've never been prouder.\"",
        ],
        "talk_younger": [
            "\"Father thinks magic is just animals with ideas. He's not entirely wrong, which is very annoying.\"",
            "\"The moon-moths came from the Whisperwood. The dust heals — not much, but enough to keep someone walking.\"",
            "\"A companion goes where its keeper goes. Into barrows, too. That's why we're careful who we sell to.\"",
        ],
    },
}


def data():
    return {"_doc": __doc__, "caravan": CARAVAN, "pawn": PAWN, "rival": RIVAL, "creatures": CREATURES}


def write():
    with open(os.path.join(D, "commerce.json"), "w") as f:
        json.dump(data(), f, indent=1, ensure_ascii=False)
    print("commerce.json written")


if __name__ == "__main__":
    write()
