"""The Living Realm (milestone 3a), adventurers: the reserve roster.

Brindlewick's eight established adventurers (Mira, Sigrun, Elowen, Kestra, Garrick, Tomas, Varn, Pip) keep
their story roles. These sixteen are the wider world's adventurers: a campaign's world seed decides which of
them are already at the Tipsy Wyvern on day 1 (and their level, purse, gear, temper, goals and friendships),
and the rest arrive later as newcomers when the roster thins (Living.newcomer). Art: make_minis.py (sheets)
and make_characters.py (portraits) with --only=<ids>.

`reserve: True` keeps them out of the starting roster unless the seed picks them; `level` and `gold` are the
centre of the seeded range.
"""
from make_data_helpers import ch, L


def adv(id, name, cls, look, age, personality, level=2, gold=70, race="Human"):
    return ch(id, name, "adventurer", look, cls=cls, level=level, gold=gold, age=age, race=race,
              personality=personality, reserve=True)


def lk(build, female, skin, hair, hair_col, armor, shirt, back, hand, cloak=None, beard="none", beard_col=None, extras=None):
    return L(build=build, female=female, skin=skin, hair=hair, hair_col=hair_col, beard=beard,
             beard_col=beard_col or hair_col, armor=armor, shirt=shirt, cloak=cloak, back=back, hand=hand,
             extras=extras or [])


CHARACTERS = [
    adv("rv_aldous", "Aldous Brack", "Fighter",
        lk("average", False, "#d8a882", "short", "#6a4a2a", "plate", "#6e6a5a", "shield", "sword", "#5a4a3a", "short"),
        38, "A grey-templed sellsword who counts every coin twice and every friend once.", 3, 90),
    adv("rv_brenna", "Brenna Thorn", "Fighter",
        lk("average", True, "#c48a66", "ponytail", "#2a1e16", "plate", "#7a3a2a", "shield", "sword", "#4a2e26"),
        26, "Ambitious and blunt; came north to make a name before her brothers do.", 2, 60),
    adv("rv_corwin", "Corwin Ashby", "Paladin",
        lk("average", False, "#e6c4a8", "short", "#c8a060", "plate", "#d8d0b8", "shield", "mace", "#c8c0a8", "stubble"),
        30, "Earnest to a fault; keeps a list of the wrongs he means to right.", 3, 80),
    adv("rv_dagny", "Dagny Ironvein", "Paladin",
        lk("dwarf", True, "#c99a76", "braid", "#8a4a28", "plate", "#6a7486", "shield", "mace", "#7e2c30"),
        44, "A dwarf of the old oaths; patient, stubborn, and unimpressed by youth.", 4, 120, "Dwarf"),
    adv("rv_ewan", "Ewan Greyleaf", "Ranger",
        lk("slim", False, "#f0dcc8", "long", "#d8d0c0", "leather", "#4e6a44", "quiver", "bow", "#3e5a34", extras=["pointed_ears"]),
        61, "An elf who has outlived three companies and trusts none of the maps.", 4, 110, "Elf"),
    adv("rv_fen", "Fen Marlow", "Ranger",
        lk("slim", True, "#d49a72", "cropped", "#6a5030", "leather", "#5e6e4a", "quiver", "bow", "#4e5a3a"),
        22, "A poacher's daughter turned tracker; quiet, quick and hungry for coin.", 1, 40),
    adv("rv_galen", "Galen Voss", "Wizard",
        lk("slim", False, "#e4c0a0", "short", "#2a1e16", "robe", "#4a3e6e", "none", "staff", "#2e2a4a", "short"),
        34, "A failed academy scholar with something to prove and a ledger of slights.", 3, 150),
    adv("rv_hesper", "Hesper Quill", "Wizard",
        lk("slim", True, "#b67c58", "long", "#1e1612", "robe", "#3e4a6e", "none", "staff", "#2e3450"),
        28, "Collects forgotten names and broken runes; forgets meals.", 2, 90),
    adv("rv_ivo", "Ivo Kettle", "Rogue",
        lk("halfling", False, "#e0b48e", "curly", "#4a3020", "leather", "#5a4a3a", "none", "dagger", "#3a3430"),
        36, "A cheerful halfling with light fingers and a heavy debt.", 2, 50, "Halfling"),
    adv("rv_juno", "Juno Sable", "Rogue",
        lk("slim", True, "#c89070", "hood", "#2a1e16", "leather", "#3a3430", "none", "dagger", "#2a2622", extras=["hood_down"]),
        25, "Never gives the same name twice; always pays her debts.", 3, 100),
    adv("rv_korvak", "Korvak Redmaw", "Barbarian",
        lk("orc", False, "#8a9a72", "mohawk", "#1e1a16", "leather", "#5a3a26", "none", "axe", extras=["tusks"]),
        33, "Wants to be remembered in a song, preferably a loud one.", 3, 40, "Half-orc"),
    adv("rv_liesl", "Liesl Harrow", "Barbarian",
        lk("average", True, "#e8c8a8", "braid", "#d8c088", "leather", "#6a3a2a", "none", "axe"),
        29, "A shepherd's widow from the high pastures; fights like the winter.", 2, 30),
    adv("rv_mattias", "Brother Mattias", "Cleric",
        lk("heavy", False, "#d8a882", "bald_fringe", "#5a4030", "robe", "#8a6e48", "pack", "mace", beard="short"),
        52, "Walked from the southern abbeys to tend the wounded of the barrows.", 3, 60),
    adv("rv_nell", "Nell Ashgrove", "Cleric",
        lk("average", True, "#ecc6a4", "bun", "#b8783a", "robe", "#c8c0a8", "pack", "mace", "#a89878"),
        31, "A hedge-priestess with steady hands and a sharper tongue.", 2, 70),
    adv("rv_oskar", "Oskar Fiddle", "Bard",
        lk("average", False, "#e2b48e", "curly", "#8a4a24", "leather", "#7e5a8a", "lute", "dagger", "#5a3e6a", "stubble"),
        27, "Writes songs about other people's victories and wants one of his own.", 2, 80),
    adv("rv_perrin", "Perrin Lark", "Bard",
        lk("halfling", True, "#f0dcc8", "long", "#c8a060", "leather", "#4a6a7a", "lute", "dagger", "#3a5a6a"),
        40, "A travelling chronicler; knows a little of everyone's business.", 3, 120, "Halfling"),
]
