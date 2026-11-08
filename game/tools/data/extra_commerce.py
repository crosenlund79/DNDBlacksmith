"""Commerce content (iteration 010): companion creatures, the rival smith's specialist work, caravan curiosities
and the five commerce characters. Imported by make_data.py (ITEMS, CHARACTERS). Importing this module also
regenerates data/commerce.json (caravan, pawnshop, rival smith, creature merchants) through make_commerce.write().

Fixed ids used by other systems (do not rename): characters rival_smith, hale_elder, hale_younger, pawnbroker,
caravan_master; companion items comp_* (type "companion", slot "companion", field `creature` = sprite id under
assets/sprites/creatures/, icon icons/<item id>).

Companion stats are among attack, protection, scouting, heal, magic, carry (plus fire for the drake). They are
plain numbers (no ranges): Items.make scales them a little with the creature's "quality" (its training).
"""
from make_data_helpers import it, ch, L


def comp(id, name, value, stats, creature, desc, tags, flying=False, magical=False, keeper="hale_elder", species=""):
    d = it(id, name, "companion", "companion", value, stats=stats, stack=False, desc=desc,
           tags=["companion"] + tags + (["flying"] if flying else []) + (["magical"] if magical else []))
    d["creature"] = creature
    d["keeper"] = keeper
    d["species"] = species or name.split()[-1].lower()
    return d


ITEMS = [
    # ---------------------------------------------------------------- companions: ordinary creatures (Bram Hale)
    comp("comp_mouser_cat", "Mouser Cat", 45, {"scouting": 2, "heal": 1}, "mouser_cat",
         "A lean tabby who has never once lost a staring match. Keeps the rats out of the rations and wakes you when something moves.",
         ["beast", "cat"], species="cat"),
    comp("comp_pack_mule", "Pack Mule", 90, {"carry": 6}, "pack_mule",
         "Stubborn, sure-footed and patient as stone. Carries what an adventurer cannot — and brings more of the spoils home.",
         ["beast", "mule"], species="mule"),
    comp("comp_fell_pony", "Fell Pony", 130, {"carry": 3, "scouting": 2, "protection": 1}, "fell_pony",
         "A shaggy hill pony, small enough for a dwarf, tough enough for the barrow roads. Knows the way home in a fog.",
         ["beast", "pony"], species="pony"),
    comp("comp_war_hound", "War Hound", 170, {"attack": 4, "protection": 2}, "war_hound",
         "A broad-chested hound in a studded collar, bred to stand between its master and anything with teeth.",
         ["beast", "hound"], species="hound"),
    comp("comp_hunting_falcon", "Hunting Falcon", 200, {"scouting": 5, "attack": 2}, "hunting_falcon",
         "A peregrine trained to the glove. Sees the ambush from a mile off and returns with a hare for supper.",
         ["bird", "falcon"], flying=True, species="falcon"),
    # ---------------------------------------------------------------- companions: magical creatures (Ellery Hale)
    comp("comp_moon_moth", "Moon-Moth", 340, {"heal": 5, "magic": 1}, "moon_moth",
         "A moth the size of a hand whose silver wing-dust closes small wounds. Glows faintly by night; sleeps in a lantern by day.",
         ["insect", "moth", "rare"], flying=True, magical=True, keeper="hale_younger", species="moon-moth"),
    comp("comp_stone_toad", "Stone-Toad Familiar", 390, {"magic": 4, "protection": 3}, "stone_toad",
         "A grey toad with a back like weathered granite. Hums with old earth-magic and turns aside blows meant for its keeper.",
         ["amphibian", "toad", "rare", "familiar"], magical=True, keeper="hale_younger", species="stone-toad"),
    comp("comp_glimmer_fox", "Glimmer-Fox", 460, {"scouting": 5, "magic": 3}, "glimmer_fox",
         "A small fox whose brush leaves a trail of pale sparks. Finds hidden doors, buried coin and the shortest way out.",
         ["beast", "fox", "rare"], magical=True, keeper="hale_younger", species="glimmer-fox"),
    comp("comp_pocket_drake", "Pocket Drake", 560, {"attack": 5, "fire": 3}, "pocket_drake",
         "A cat-sized drake with ember-red scales and opinions. Breathes a fist of flame at whatever its keeper glares at.",
         ["dragon", "drake", "rare", "fire"], flying=True, magical=True, keeper="hale_younger", species="drake"),

    # ---------------------------------------------------------------- the rival smith's specialist work (sea-bronze)
    it("cutlass_seabronze", "Sea-Bronze Cutlass", "weapon", "weapon", 260,
       stats={"attack": [13, 18], "durability": 130, "speed": 2}, tags=["seabronze", "rival"],
       desc="A broad boarding cutlass of sea-bronze: it will not rust in brine or blood. Maren Tallowgate's mark on the ricasso."),
    it("harpoon_barbed", "Barbed Harpoon-Spear", "weapon", "weapon", 300,
       stats={"attack": [15, 21], "durability": 115}, tags=["seabronze", "rival"],
       desc="A whaler's harpoon re-hafted as a war-spear; the barbs hold whatever they bite."),
    it("buckler_seabronze", "Sea-Bronze Buckler", "shield", "shield", 185,
       stats={"protection": [6, 9], "durability": 125, "speed": 2}, tags=["seabronze", "rival"],
       desc="A small hammered buckler, green at the rim where the sea has kissed it. Light enough to swim with."),
    it("helm_brinecap", "Brine-Cap Helm", "helmet", "helmet", 160,
       stats={"protection": [4, 6], "durability": 115, "ward": 2}, tags=["seabronze", "rival"],
       desc="An open sea-bronze cap with a leather nape-guard and a salt-ward scratched inside the crown."),
    it("sabre_ripple", "Ripple-Steel Sabre", "weapon", "weapon", 640,
       stats={"attack": [19, 26], "durability": 160, "speed": 3}, tags=["ripple_steel", "rival", "rare"],
       desc="Southern crucible steel, folded until the blade shows water. Maren buys the cakes from a ship's cook who will not say where."),

    # ---------------------------------------------------------------- caravan curiosities
    it("curio_tide_compass", "Tide Compass", "curio", None, 140, tags=["curio"],
       desc="A brass compass whose needle points not north but toward the nearest open water."),
    it("curio_songbird", "Clockwork Songbird", "curio", None, 185, tags=["curio"],
       desc="A gilt songbird on a perch. Wound with a tiny key, it sings three bars of a lullaby nobody in Brindlewick knows."),
    it("curio_seer_glass", "Seer's Lens", "curio", None, 120, tags=["curio"],
       desc="A smoky glass lens in a bone ring. Through it, candle-flames look a little like faces."),
    it("curio_star_chart", "Southern Star Chart", "curio", None, 160, tags=["curio"],
       desc="An inked chart of stars that never rise over Brindlewick, with notes in three hands and two languages."),
]

CHARACTERS = [
    ch("rival_smith", "Maren Tallowgate", "villager",
       L(build="heavy", female=True, skin="#c48a66", hair="braid", hair_col="#b05a2a", beard="none", armor="apron",
         shirt="#3e4a6e", cloak=None, back="none", hand="hammer", extras=["scalp_scar"]),
       age=46, title="Smith of the Salt Anvil", work="rival_smith",
       personality="Loud, warm and fiercely competitive; keeps score of everything, laughs at her own jokes, and swears by salt, "
                   "sea-bronze and a good rival. Forged for the fishing fleets down the coast before she came to Brindlewick."),
    ch("pawnbroker", "Silas Quell", "villager",
       L(build="slim", female=False, skin="#e0b090", hair="bald_fringe", hair_col="#9a948a", beard="stubble", beard_col="#9a948a",
         armor="none", shirt="#5a4a3a", cloak="#2a2622", back="none", hand="none", extras=["spectacles"]),
       age=61, title="Pawnbroker", work="pawn",
       personality="Soft-spoken and exact; weighs everything twice, remembers every ticket, and never asks where a thing came from."),
    ch("caravan_master", "Ottavio Brask", "villager",
       L(build="heavy", female=False, skin="#a8704e", hair="curly", hair_col="#1e1612", beard="short", beard_col="#2a1e16",
         armor="leather", shirt="#8a3e2c", cloak="#7e2c30", back="pack", hand="staff", extras=[]),
       age=52, title="Caravan Master", work="caravan",
       personality="An expansive storyteller who prices everything twice — once for the tale, once for the goods."),
    ch("hale_elder", "Bram Hale", "villager",
       L(build="heavy", female=False, skin="#d49a72", hair="bald_fringe", hair_col="#a8a094", beard="short", beard_col="#c8c2b4",
         armor="leather", shirt="#6e7a4a", cloak="#4e5a3a", back="none", hand="basket", extras=[]),
       age=64, title="Keeper of Beasts", work="creatures",
       personality="Big, slow-spoken and gentle; talks to animals more readily than to people, never hurries a frightened creature, "
                   "and laughs down in his chest. Has raised hounds, falcons and mules on Hale Farm for forty years."),
    ch("hale_younger", "Ellery Hale", "villager",
       L(build="slim", female=False, skin="#e8c0a0", hair="curly", hair_col="#8a4a24", beard="none",
         armor="none", shirt="#7e5a8a", cloak="#5a3e6a", back="pack", hand="none", extras=["spectacles"]),
       age=27, title="Keeper of Curious Creatures", work="creatures",
       personality="Bram's son: a scholar who studied at the Collegium and came home with a moth in his pocket. Talks too fast "
                   "when excited, fills notebooks with wing-patterns, and apologises to every creature before he picks it up."),
]

try:
    import make_commerce
    make_commerce.write()
except Exception as _e:  # never break make_data.py because of the commerce catalogue
    print("extra_commerce: commerce.json not written:", _e)
