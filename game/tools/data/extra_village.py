"""Village people added in iteration 009 (character worker): Róisín, the Velvet Lantern's red-haired companion.

Her romance (talk options, stages, contract buyout, gifts) lives in scripts/systems/roisin.gd.
"""
from make_data_helpers import ch, L

CHARACTERS = [
    ch("roisin", "Róisín", "companion",
       L(build="slim", female=True, skin="#f2d4bc", hair="long", hair_col="#cc3e12", beard="none", armor="robe",
         shirt="#2c5a3e", cloak=None, back="none", hand="none", extras=[]),
       age=29, title="Companion at the Velvet Lantern",
       personality="Sharp-witted sailor's daughter who hates being underestimated; mends broken clockwork for fun; "
                   "saving to buy out her contract and open a tea house.",
       home="inn_upstairs", likes=["herb_moonwort", "herb_emberleaf", "gem_moonstone", "relic_coin", "amulet_silver"],
       dislikes=["ale_mug"]),
]
