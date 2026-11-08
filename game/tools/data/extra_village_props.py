"""Iteration 009 village props (drawn by tools/art/make_village_art.py): nature & boundaries, grit, the pond,
the harbour, the herbalist, Barnaby's Ironfront basement and the stable, cooper and chandler."""


def P(w, h, solid=True, desc=""):
    return dict(size=[w, h], solid=solid, desc=desc)


PROPS = {
    # nature & boundaries
    "reeds": P(64, 64, False, "clump of reeds and bulrushes at a water's edge"),
    "lily_pads": P(96, 64, False, "lily pads with one flower, floating"),
    "duck": P(32, 28, False, "mallard on the water, seen from above"),
    "rowboat": P(112, 48, False, "clinker rowing boat moored at the jetty, oars shipped"),
    "fern": P(56, 48, False, "woodland fern"),
    "undergrowth": P(112, 80, False, "low bramble and shrub tangle at the edge of a wood"),
    "hedge_h": P(128, 40, desc="clipped hedge, horizontal"),
    "hedge_v": P(40, 128, desc="clipped hedge, vertical"),
    "stone_wall_h": P(128, 32, desc="mossy dry-stone wall, horizontal"),
    "stone_wall_v": P(32, 128, desc="mossy dry-stone wall, vertical"),
    "crop_rows": P(192, 128, False, "tilled strip with rows of cabbages and leeks"),
    "stump": P(48, 48, desc="tree stump with roots and moss"),
    # grit
    "puddle": P(96, 56, False, "muddy rain puddle"),
    "mud_patch": P(128, 80, False, "trampled mud with boot prints and wheel marks"),
    "refuse_heap": P(80, 64, desc="midden: peelings, a cracked pot, rags"),
    "broken_crate": P(64, 56, desc="smashed crate with loose planks and straw"),
    "moss_decal": P(96, 40, False, "moss and grime creeping up a wall base"),
    "chopping_block": P(48, 52, desc="chopping block with an axe and kindling"),
    # harbour
    "mooring_post": P(32, 40, desc="timber bollard with a rope"),
    "net_rack": P(128, 56, desc="fishing net hung on trestles to dry"),
    "net_pile": P(72, 48, desc="heaped fishing net with floats"),
    "rope_coil": P(48, 48, False, "coil of hemp rope"),
    "crate_stack": P(96, 96, desc="stack of cargo crates and a bale"),
    "lobster_pots": P(64, 48, desc="two wicker lobster pots"),
    "anchor": P(72, 72, False, "old iron anchor lying on the quay"),
    "harbour_booth": P(128, 112, desc="harbourmaster's booth: plank roof, serving hatch with ledger, bell and tide slate"),
    # herbalist
    "herb_counter": P(256, 64, desc="herbalist's counter: mortar, brass scales, paper twists, jars, sage"),
    "jar_shelf": P(128, 40, desc="wall shelf of stoppered clay jars and bottles"),
    "herb_garlands": P(192, 48, False, "herb bundles hung from a ceiling string"),
    "herb_baskets": P(96, 72, desc="baskets of leaves, lavender, marigold and rosehips"),
    "herb_garden": P(128, 96, False, "stone-edged herb bed"),
    "potting_bench": P(128, 56, desc="potting bench with seedlings and a trowel"),
    # Barnaby's Ironfront den
    "felt_table": P(288, 176, desc="Ironfront game table: green felt battlefield, model tanks, cards, dice, tankards"),
    "war_map_wall": P(192, 40, desc="wall-mounted campaign map with front lines and pins"),
    "diagram_board": P(128, 40, desc="chalk board of tank diagrams and formations"),
    "tank_shelf": P(128, 40, desc="shelf of painted model tanks"),
    "diorama_table": P(160, 96, desc="terrain diorama with a river, a broken bridge and miniature vehicles"),
    "card_cabinet": P(128, 44, desc="cabinet of card drawers with brass pulls"),
    "card_binders": P(128, 40, desc="shelf of card binders and boxed decks"),
    "paint_desk": P(128, 64, desc="hobby desk: paint pots, brushes, a half-painted tank, lamp"),
    "standing_lamp": P(40, 40, desc="brass standing lamp seen from above"),
    # stable, cooper, chandler
    "horse": P(72, 144, desc="bay horse standing in a stall"),
    "water_trough": P(112, 44, desc="wooden water trough"),
    "saddle_rack": P(128, 40, desc="wall rack with two saddles and a bridle"),
    "barrel_stack": P(112, 96, desc="cooper's finished casks"),
    "stave_bundle": P(112, 48, desc="bundle of barrel staves bound with iron"),
    "hoop_pile": P(64, 64, False, "pile of iron barrel hoops"),
    "candle_rack": P(128, 40, desc="chandler's rack of dipped tapers"),
    "wax_vat": P(80, 80, desc="stone wax vat over a low fire"),
}
