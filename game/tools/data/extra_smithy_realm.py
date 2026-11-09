"""The Living Realm (milestone 2a) — the evolving smithy's decor (drawn by tools/art/make_smithy_realm_art.py):
the craft banners that mark each workshop room, their gilt Masterwork trim and the aetheric lift's platform."""


def P(w, h, solid=True, desc=""):
    return dict(size=[w, h], solid=solid, desc=desc)


PROPS = {
    "banner_classic": P(64, 80, False, "craft banner on the north wall: crossed hammer over an anvil (Smithing)"),
    "banner_stitching": P(64, 80, False, "craft banner: needle, thread and shears (Leatherworking & Tailoring)"),
    "banner_runecraft": P(64, 80, False, "craft banner: a carved rune stone (Runecrafting)"),
    "banner_alchemy": P(64, 80, False, "craft banner: a round flask with a sprig (Alchemy)"),
    "banner_arcane": P(64, 80, False, "craft banner: a violet sigil star (Arcane Metalworking)"),
    "banner_gilt": P(64, 80, False, "gilt trim and tassels over a craft banner — a Masterwork room"),
    "lift_platform": P(96, 96, False, "the aetheric lift: Ilse's old hoist platform, a brass ring and a ley-stone"),
}
