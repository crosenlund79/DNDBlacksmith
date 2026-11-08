"""Iteration 010 village props (drawn by tools/art/make_village10_art.py): street signs with trade emblems (never
solid: they hang beside doors and are drawn above the actors), street lamps, the pawnshop, the rival smith's forge,
the Hales' cottage and menagerie, the caravan camp, the ceremony stage, paddock gates and grave plots."""
from make_data_helpers import P

_SIGNS = {
    "sign_smithy": "hammer over an anvil", "sign_inn": "a foaming tankard", "sign_grocer": "wheat sheaf and apple",
    "sign_herbalist": "mortar with herb sprigs", "sign_chapel": "the dawn sun", "sign_barnaby": "a tiny tank",
    "sign_cooper": "a barrel", "sign_stable": "a horseshoe", "sign_chandler": "a lit candle", "sign_netloft": "a fish on a net",
    "sign_carpenter": "a saw and a plane", "sign_farm": "a pitchfork and sheaf", "sign_laundry": "a shirt on the line",
    "sign_cottage_a": "a painted flower", "sign_cottage_b": "a little house", "sign_rival": "crossed hammers over a flame",
    "sign_menagerie": "a paw print and a feather", "sign_harbour": "an anchor", "sign_pawn": "the pawnbroker's three gilt balls",
}

PROPS = {k: P(80, 48, False, "hanging street sign: " + v) for k, v in _SIGNS.items()}
PROPS.update({
    # street lamp: placed by village10.gd with its foot at the bottom centre (own small collision), glow shown at night
    "street_lamp": P(64, 128, False, "iron street lamp on a stone foot, lantern on a scrolled arm (three-quarter view)"),
    "street_lamp_glow": P(64, 128, False, "night overlay: the street lamp's lit glass and halo"),
    # pawnshop
    "pawn_counter": P(192, 56, desc="pawnbroker's counter: brass scales, pocket watch, ring box, tagged parcels, ledger"),
    "curio_shelf": P(128, 40, desc="shelf of odd pawned goods: stuffed owl, globe, bottles, dented helm, clock, price tags"),
    "display_case": P(96, 56, desc="glass-topped case of rings, lockets and trinkets"),
    # the rival smith
    "rival_forge": P(128, 96, desc="the rival smith's stone forge with glowing coals and bellows"),
    "rival_anvil": P(80, 48, desc="anvil on an oak stump with a hammer"),
    "rival_counter": P(160, 56, desc="the rival smith's sales counter with a blade, an axe and mail"),
    "rival_display": P(160, 40, desc="wall rack of finished weapons and a shield"),
    # the Hales
    "creature_cages": P(128, 48, desc="shelf of wicker and iron cages with small creatures, eyes glinting"),
    "bestiary_desk": P(128, 56, desc="desk with an open bestiary, specimen jars, a quill and a feather"),
    "rabbit_hutch": P(96, 72, desc="wooden rabbit hutch with a wire run and two rabbits"),
    "chicken_coop": P(112, 96, desc="small shingled hen house with a run and three hens"),
    "arcane_enclosure": P(176, 128, desc="ring of standing stones and an iron rail around a glowing ward; a drakeling sleeps in a nest"),
    "feed_scatter": P(64, 48, False, "scattered grain and chaff"),
    "hay_rack": P(80, 48, desc="wooden hay rack"),
    "fence_gate_h": P(64, 24, desc="field gate, horizontal"),
    "fence_gate_v": P(24, 64, desc="field gate, vertical"),
    # the caravan camp
    "caravan_wagon": P(224, 144, desc="covered trader's wagon from above: striped painted hood, four wheels, shafts, crates"),
    "campfire": P(72, 72, desc="stone fire ring with logs and embers"),
    "log_seat": P(96, 40, desc="a log laid by the fire as a seat"),
    "tether_post": P(32, 32, desc="tethering post with a rope"),
    "caravan_pennant": P(80, 40, desc="a pole with a swallow-tailed burgundy pennant, the caravan camp's mark"),
    # the square's ceremony stage
    "square_stage": P(352, 208, False, "plank ceremony stage with steps, drapes and a red runner (walkable)"),
    "podium_board": P(128, 64, desc="the square's honours board with brass plaques and a lectern"),
    "bunting": P(384, 56, False, "two swags of bunting in burgundy, cream, gilt and blue"),
    # graveyard
    "grave_plot": P(72, 48, False, "an unused grave plot pegged out with string"),
})
