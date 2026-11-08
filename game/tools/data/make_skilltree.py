"""Generates game/data/skilltree.json — the Blacksmith's Skill Tree.
Run: python3 tools/data/make_skilltree.py   (make_data.py also runs it)

Six branches of nodes. A node is learned once its requirements are met:
  requires.skill            [skill_id, level]       a player skill level
  requires.nodes            [node ids]              prerequisite nodes (drawn as lines)
  requires.flags            [flag ids]              knowledge / world discoveries (see FLAGS for hints)
  requires.stations_installed [station ids]         installed in the workshop (Property.is_installed)
  requires.items_seen       [item ids]              the smith has held the material at least once
  requires.items            {item id: n}            consumed when learning
  requires.gold             n                       tuition, paid when learning
and unlocks:
  unlocks.recipes / unlocks.stations (eligible for purchase and installation) / unlocks.techniques
  secret: true   hidden ("???") until its flags are known.
Every recipe and every station is unlocked by exactly one node (validated below).
Nodes listed in START are known from a new game.
"""
import json
import os
import sys

HERE = os.path.dirname(__file__)
D = os.path.join(HERE, "..", "..", "data")
sys.path.insert(0, HERE)

BRANCHES = [
    dict(id="mining", name="Mining & Metallurgy", skill="mining", x=0, colour="#8a6a3a",
         desc="Ores, refining and alloys — from honest iron to orichalcum."),
    dict(id="smithing", name="Traditional Smithing", skill="smithing", x=1, colour="#7e2418",
         desc="The forge and the anvil: blades, armour and the master's eye."),
    dict(id="arcane", name="Arcane Metalworking", skill="arcane_metalwork", x=2, colour="#5a3e8a",
         desc="Magic bound into the metal itself. Opens once a smith can handle leyline energy."),
    dict(id="runecraft", name="Runecrafting", skill="runecraft", x=3, colour="#2e4e6e",
         desc="Reading, restoring, engraving and finally inventing runes."),
    dict(id="alchemy", name="Alchemy", skill="alchemy", x=4, colour="#3e6a2e",
         desc="Oils, distillations, reagents, infusions and exotic compounds."),
    dict(id="leather", name="Leatherworking & Enchanted Stitching", skill="enchanted_stitching", x=5, colour="#6a4422",
         desc="Hides to monster leather, linen to ethereal thread — and dragon scale."),
]

# Knowledge flags: where a player can learn them (shown as hints in the tree).
FLAGS = {
    "rune_knowledge": dict(name="Rune lore", hint="learned by restoring an old runestone from a weathered tablet"),
    "dragon_lore": dict(name="Dragon lore", hint="rumoured in the harbour taverns — or learned by studying a dragon's scale or bone"),
    "recipe_starsteel": dict(name="The starsteel notes", hint="a Forgotten Recipe found among the relics"),
    "found_mithril": dict(name="Mithril found", hint="hold mithril ore for the first time"),
}


def T(id, name, desc, quality=0, **flt):
    """A technique: descriptive, optionally a small craftsmanship bonus (percentage points) for matching recipes.
    Filter keys: discipline, category, material, recipes (lists)."""
    t = dict(id=id, name=name, desc=desc)
    if quality:
        t["quality"] = quality
        t["filter"] = {k: v for k, v in flt.items()}
    return t


def N(id, branch, name, desc, x, y, skill=None, nodes=None, flags=None, stations=None, seen=None, items=None, gold=0,
      recipes=None, unlock_stations=None, techniques=None, secret=False):
    req = {}
    if skill:
        req["skill"] = list(skill)
    if nodes:
        req["nodes"] = nodes
    if flags:
        req["flags"] = flags
    if stations:
        req["stations_installed"] = stations
    if seen:
        req["items_seen"] = seen
    if items:
        req["items"] = items
    if gold:
        req["gold"] = gold
    n = dict(id=id, branch=branch, name=name, desc=desc, x=x, y=y, requires=req,
             unlocks=dict(recipes=recipes or [], stations=unlock_stations or [], techniques=techniques or []))
    if secret:
        n["secret"] = True
    return n


START = ["s_basic", "l_basic"]

NODES = [
    # ------------------------------------------------------------ Traditional Smithing
    N("s_basic", "smithing", "Basic Ironworking & Repairs", "The apprentice's craft: heat, hammer, quench and grind honest iron.", 1, 0,
      recipes=["smelt_iron", "iron_longsword", "hand_axe", "flanged_mace", "round_shield", "iron_helm"],
      unlock_stations=["forge", "anvil", "crucible", "quench_trough", "grinding_wheel"],
      techniques=[T("t_repairs", "Field repairs", "Dented and notched gear can be ground and re-tempered at the grinding wheel.")]),
    N("s_blades", "smithing", "Simple Blades & Armour", "Once your first sword has left the anvil: plate for the body and silver for the hand.", 1, 1,
      skill=("smithing", 4), nodes=["s_basic"], seen=["sword_iron"],
      recipes=["iron_cuirass", "silver_band"]),
    N("s_steel", "smithing", "Steelworking", "Folded, normalised steel: keener edges and lighter plate.", 1, 2,
      skill=("smithing", 5), nodes=["s_blades", "m_alloys"],
      recipes=["steel_longsword", "steel_cuirass"]),
    N("s_heat", "smithing", "Advanced Heat Treatment", "Interrupted quenches, oil tempering and the long, patient normalise.", 1, 3,
      skill=("smithing", 6), nodes=["s_steel"],
      recipes=["kite_shield"],
      techniques=[T("t_quench", "Interrupted quench", "+2% craftsmanship on classic weapons.", 2, discipline=["classic"], category=["weapon"])]),
    N("s_runed", "smithing", "Runed Steel", "Steel, a set rune and a flame-quenched edge in one blade — four crafts meet at the anvil.", 1.42, 4.2,
      skill=("smithing", 6), nodes=["s_heat", "r_engrave", "al_simple"],
      recipes=["emberwarden_longsword"]),
    N("s_alloy", "smithing", "Alloy Production", "Reading a melt by its colour; mixing metals that do not want to mix.", 0.86, 4.6,
      skill=("smithing", 7), nodes=["s_heat", "m_rare"],
      techniques=[T("t_alloy", "Alloy sense", "+2% craftsmanship when working steel or starmetal.", 2, material=["steel", "starmetal"])]),
    N("s_starsteel", "smithing", "Forgotten Starsteel", "A smith's notes from another age describe a blade folded with fallen star-metal.", 0.5, 5.7,
      skill=("smithing", 7), nodes=["s_alloy"], flags=["recipe_starsteel"], secret=True,
      recipes=["starsteel_blade"]),
    N("s_master", "smithing", "Master Smithing", "The hand-and-a-half blade, kept straight over its whole length.", 1, 6.0,
      skill=("smithing", 8), nodes=["s_alloy"], gold=150,
      recipes=["steel_bastard_sword"],
      techniques=[T("t_master_eye", "Master's eye", "+2% craftsmanship on all classic smithing.", 2, discipline=["classic"])]),
    N("s_armour", "smithing", "Master Armourcraft", "Plate that moves with its wearer — the knowledge every legendary armour rests on.", 1, 7.4,
      skill=("smithing", 8), nodes=["s_master"], gold=250,
      techniques=[T("t_armourcraft", "Master armourcraft", "+3% craftsmanship on all armour.", 3, category=["armour"])]),

    # ------------------------------------------------------------ Mining & Metallurgy
    N("m_common", "mining", "Common Ores & Refining", "Sorting good ore from slag and keeping a clean melt.", 0, 0,
      skill=("mining", 2), nodes=["s_basic"],
      techniques=[T("t_assay", "Assayer's eye", "+2% craftsmanship when smelting and refining.", 2, category=["material"], discipline=["classic"])]),
    N("m_alloys", "mining", "Ordinary Alloys", "Iron and carbon become steel — with the bellows driving the heat.", 0, 1,
      skill=("mining", 2), nodes=["m_common"], gold=40,
      recipes=["smelt_steel"], unlock_stations=["bellows"]),
    N("m_rare", "mining", "Rare Mineral Identification", "Garnet from glass, moonstone from quartz, silver from tin.", 0, 2.2,
      skill=("mining", 3), nodes=["m_alloys"],
      techniques=[T("t_rare_minerals", "Rare minerals", "Gems and rare ores in expedition loot are recognised at a glance.")]),
    N("m_adv", "mining", "Advanced Processing", "Double refining, fluxes and slow cooling for flawless stock.", 0, 3.2,
      skill=("mining", 3), nodes=["m_rare"],
      techniques=[T("t_processing", "Advanced processing", "+2% craftsmanship on every material recipe.", 2, category=["material"])]),
    N("m_mithril", "mining", "Mithril", "The pale metal that drinks magic. It must be charged before it can be worked.", 0, 4.2,
      skill=("mining", 3), nodes=["m_adv"], seen=["ore_mithril"],
      techniques=[T("t_mithril", "Mithril lore", "Mithril can be charged at the Arcane Crucible.")]),
    N("m_adamant", "mining", "Adamantine", "Near-unbreakable ore that only a bound ward can tame.", 0, 6.4,
      skill=("mining", 4), nodes=["m_mithril"], seen=["ore_adamantine"],
      techniques=[T("t_adamant", "Adamantine lore", "Adamantine can be charged once metals can be charged.")]),
    N("m_magic", "mining", "Magical Alloys", "Orichalcum: copper-gold of the sea-kings, smelted with aether dust in warded fire.", 0, 7.6,
      skill=("mining", 4), nodes=["m_adamant", "ar_crucible"], seen=["ore_orichalcum"],
      recipes=["smelt_orichalcum"]),

    # ------------------------------------------------------------ Arcane Metalworking (initially locked)
    N("ar_energy", "arcane", "Magical Energy Handling", "Feeling the leyline in the metal — and surviving it. You sacrifice a nugget of mithril to learn how it drinks magic.", 2, 4.4,
      skill=("smithing", 6), nodes=["s_heat", "r_engrave", "m_mithril"], items={"ore_mithril": 1},
      techniques=[T("t_leyline", "Leyline sense", "You can tell a charged ingot from a dead one by touch.")]),
    N("ar_crucible", "arcane", "The Arcane Crucible", "Warded fire that melts mithril while binding magic into it.", 2, 5.4,
      skill=("arcane_metalwork", 0), nodes=["ar_energy"], gold=150,
      recipes=["charge_mithril"], unlock_stations=["arcane_crucible", "leyline_conductor", "aetheric_stabilizer"]),
    N("ar_spellbind", "arcane", "Spellbinding", "Locking a spell pattern into cooling metal on the floor circle.", 2, 6.4,
      skill=("arcane_metalwork", 1), nodes=["ar_crucible"], stations=["arcane_crucible"],
      recipes=["mithril_runeblade"], unlock_stations=["spellbinding_array", "arcane_anvil"]),
    N("ar_charged", "arcane", "Charged Metals", "Charging the stubborn metals: adamantine takes a bound ward.", 2, 7.4,
      skill=("arcane_metalwork", 2), nodes=["ar_spellbind", "m_adamant"],
      recipes=["charge_adamantine"]),
    N("ar_plating", "arcane", "Mithril Armour Plating", "Running charged mithril into plate and hammering it over steel.", 2, 8.4,
      skill=("arcane_metalwork", 3), nodes=["ar_charged", "al_reagents"], stations=["arcane_crucible"],
      recipes=["mithril_plated_cuirass"]),
    N("ar_adamant", "arcane", "Adamantine Equipment", "Warplate with the ward in the metal itself.", 2, 9.4,
      skill=("arcane_metalwork", 4), nodes=["ar_plating"],
      recipes=["adamantine_warplate"]),
    N("ar_intrinsic", "arcane", "Intrinsic Magical Properties", "The bound magic becomes part of the piece's nature.", 2, 10.4,
      skill=("arcane_metalwork", 4), nodes=["ar_adamant"],
      techniques=[T("t_intrinsic", "Intrinsic properties", "+3% craftsmanship on all arcane metalwork.", 3, discipline=["arcane"])]),
    N("ar_legend", "arcane", "Legendary Arcane Craftsmanship", "Master armourcraft, prepared dragon scale and bound magic: the dragon's own armour.", 2, 11.6,
      skill=("arcane_metalwork", 5), nodes=["ar_intrinsic", "s_armour", "l_dragon"],
      recipes=["dragonscale_armor"]),

    # ------------------------------------------------------------ Runecrafting
    N("r_identify", "runecraft", "Identify Existing Runes", "Reading the runes already carved on relics and tablets.", 3, 0,
      skill=("runecraft", 1), nodes=["s_basic"],
      techniques=[T("t_rune_reading", "Rune reading", "You can name the runes on weathered tablets and old blades.")]),
    N("r_clean", "runecraft", "Clean & Restore Runestones", "Washing away grave-crust and polishing an old face back.", 3, 1,
      skill=("runecraft", 1), nodes=["r_identify"], gold=40,
      recipes=["restore_runestone"], unlock_stations=["rune_cleansing_basin", "rune_polishing_wheel"]),
    N("r_blank", "runecraft", "Prepare Blank Stones", "Cleaving raw runestone along its grain into sound blanks.", 3, 2,
      skill=("runecraft", 1), nodes=["r_clean"], seen=["runestone_blank"], gold=40,
      unlock_stations=["rune_cutting_bench"],
      techniques=[T("t_true_cleave", "True cleaving", "+2% craftsmanship on runestones.", 2, category=["runestone"])]),
    N("r_engrave", "runecraft", "Engrave Basic Symbols", "The ward rune, and a garnet seated in silver.", 3, 3,
      skill=("runecraft", 2), nodes=["r_blank"],
      recipes=["ward_runestone", "garnet_ring"], unlock_stations=["rune_engraving_stand", "resonance_pedestal"]),
    N("r_stabilise", "runecraft", "Stabilise Magical Inscriptions", "Runes that burn or freeze without cracking their stone.", 3, 4,
      skill=("runecraft", 3), nodes=["r_engrave"],
      recipes=["ember_runestone", "frost_runestone", "sapphire_amulet"]),
    N("r_original", "runecraft", "Create Original Runes", "Designing a rune no tablet ever showed — your own.", 3, 5,
      skill=("runecraft", 4), nodes=["r_stabilise"], flags=["rune_knowledge"],
      recipes=["original_runestone"]),
    N("r_combo", "runecraft", "Complex Runic Combinations", "Three runes tuned to sing as one chord.", 3, 6,
      skill=("runecraft", 5), nodes=["r_original"],
      recipes=["concord_runestone"]),
    N("r_master", "runecraft", "Master Runecrafting", "A rune-master's steadiness at every runecraft station.", 3, 7,
      skill=("runecraft", 6), nodes=["r_combo"], gold=200,
      techniques=[T("t_runemaster", "Master runewright", "+3% craftsmanship on all runecraft.", 3, discipline=["runecraft"])]),

    # ------------------------------------------------------------ Alchemy
    N("al_simple", "alchemy", "Simple Mixtures & Treatments", "Mortar, cauldron and rack: a healing draught and how to treat a blade.", 4, 0,
      skill=("alchemy", 1), nodes=["s_basic"],
      recipes=["healing_draught"], unlock_stations=["mortar_station", "cauldron", "infusion_rack"],
      techniques=[T("t_treatments", "Treatments", "Oils and coatings can be brushed onto equipment at the infusion rack.")]),
    N("al_oils", "alchemy", "Basic Weapon Oils", "Distilling emberleaf into whetstone oil.", 4, 1,
      skill=("alchemy", 1), nodes=["al_simple"], gold=25,
      recipes=["whetstone_oil"], unlock_stations=["alembic"]),
    N("al_purify", "alchemy", "Purification & Distillation", "Separating volatile oils into flame and frost coatings.", 4, 2,
      skill=("alchemy", 2), nodes=["al_oils"],
      recipes=["flame_coating", "frost_coating"], unlock_stations=["reagent_table"]),
    N("al_reagents", "alchemy", "Advanced Reagents", "Silverleaf quintessence: the binder for charged plate.", 4, 3.4,
      skill=("alchemy", 3), nodes=["al_purify"], seen=["herb_silverleaf"],
      recipes=["distil_quintessence"]),
    N("al_infusion", "alchemy", "Magical Infusions", "Aether dust steeped into an infusion that lends magic.", 4, 4.6,
      skill=("alchemy", 4), nodes=["al_reagents"], seen=["reagent_aether_dust"],
      recipes=["aether_infusion"],
      techniques=[T("t_infusions", "Magical infusions", "Infusions can be brushed onto equipment like coatings.")]),
    N("al_exotic", "alchemy", "Exotic Compounds", "Wyrm ash and bloodroot: fire that clings.", 4, 5.8,
      skill=("alchemy", 5), nodes=["al_infusion"], seen=["reagent_wyrm_ash"],
      recipes=["wyrmfire_coating"]),

    # ------------------------------------------------------------ Leatherworking & Enchanted Stitching
    N("l_basic", "leather", "Ordinary Leatherwork", "Curing hides, cutting belts and gloves.", 5, 0,
      recipes=["cure_leather", "leather_belt", "leather_gloves"], unlock_stations=["stitching_table", "leather_vat"]),
    N("l_armour", "leather", "Boots, Belts & Simple Armour", "Jerkins, boots, and a ranger's bow; fitted on the mannequin.", 5, 1,
      skill=("enchanted_stitching", 1), nodes=["l_basic"], gold=20,
      recipes=["leather_boots", "leather_jerkin", "ranger_boots", "hunting_bow"], unlock_stations=["fitting_mannequin"]),
    N("l_threads", "leather", "Magical Threads", "Spinning moonlit thread that holds an enchantment.", 4.68, 2.2,
      skill=("enchanted_stitching", 3), nodes=["l_armour"],
      recipes=["yew_longbow"], unlock_stations=["thread_spinner"]),
    N("l_hides", "leather", "Special Hides & Bear Leather", "Curing a bear pelt into thick, warm leather — and armour from it.", 5.32, 2.2,
      skill=("enchanted_stitching", 2), nodes=["l_armour"], seen=["bear_pelt"],
      recipes=["cure_bear_leather", "bearhide_brigandine"]),
    N("l_enchanted", "leather", "Enchanted Stitching", "Ward sigils embroidered into leather and cloth.", 4.68, 3.4,
      skill=("enchanted_stitching", 3), nodes=["l_threads"],
      recipes=["warded_gloves", "embroidered_hood"], unlock_stations=["embroidery_frame"]),
    N("l_exotic", "leather", "Exotic Monster Materials", "Troll and wyvern hide tanned into wyrm leather.", 5, 4.6,
      skill=("enchanted_stitching", 4), nodes=["l_enchanted", "l_hides"], seen=["troll_hide"],
      recipes=["cure_troll_leather", "cure_wyvern_leather", "wyrmleather_boots"]),
    N("l_dragon", "leather", "Dragon-scale Preparation", "Brining, trimming and lacing true dragon scale without dulling its fire.", 5, 6.0,
      skill=("enchanted_stitching", 5), nodes=["l_exotic"], flags=["dragon_lore"], seen=["dragon_scale"],
      techniques=[T("t_dragon_scale", "Dragon-scale preparation", "Dragon scale and bone can be worked into armour.")]),
]


def validate(nodes, recipes, stations):
    ids = {n["id"] for n in nodes}
    assert len(ids) == len(nodes), "duplicate node id"
    by = {n["id"]: n for n in nodes}
    for n in nodes:
        assert n["branch"] in {b["id"] for b in BRANCHES}, n["id"]
        for p in n["requires"].get("nodes", []):
            assert p in ids, (n["id"], p)
        for f in n["requires"].get("flags", []):
            assert f in FLAGS, (n["id"], f)
    # no cycles
    state = {}

    def visit(i, path):
        if state.get(i) == 1:
            raise AssertionError("cycle: " + " -> ".join(path + [i]))
        if state.get(i) == 2:
            return
        state[i] = 1
        for p in by[i]["requires"].get("nodes", []):
            visit(p, path + [i])
        state[i] = 2
    for i in ids:
        visit(i, [])

    def ancestors(i):
        out, todo = set(), list(by[i]["requires"].get("nodes", []))
        while todo:
            p = todo.pop()
            if p not in out:
                out.add(p)
                todo += by[p]["requires"].get("nodes", [])
        return out | set(START)
    rec_node, st_node = {}, {}
    for n in nodes:
        for r in n["unlocks"]["recipes"]:
            assert r not in rec_node, ("recipe unlocked twice", r)
            rec_node[r] = n["id"]
        for s in n["unlocks"]["stations"]:
            assert s not in st_node, ("station unlocked twice", s)
            st_node[s] = n["id"]
    rids = {r["id"] for r in recipes}
    assert set(rec_node) == rids, ("recipe coverage", rids ^ set(rec_node))
    sids = {s["id"] for s in stations}
    assert set(st_node) == sids, ("station coverage", sids ^ set(st_node))
    for r in recipes:
        ni = rec_node[r["id"]]
        ok = ancestors(ni) | {ni}
        for s in r["steps"]:
            assert st_node[s] in ok, ("station %s for %s is unlocked by %s, not before %s" % (s, r["id"], st_node[s], ni))
    return rec_node, st_node


def build():
    import make_recipes
    stations = json.load(open(os.path.join(D, "stations.json")))
    rec_node, st_node = validate(NODES, make_recipes.recipes, stations)
    return dict(_doc=__doc__.strip().split("\n")[0], branches=BRANCHES, flags=FLAGS, start=START, nodes=NODES,
                recipe_node=rec_node, station_node=st_node)


def main():
    data = build()
    with open(os.path.join(D, "skilltree.json"), "w") as f:
        json.dump(data, f, indent=1, ensure_ascii=False)
    print("skilltree.json: %d nodes in %d branches, %d recipes, %d stations" % (
        len(data["nodes"]), len(data["branches"]), len(data["recipe_node"]), len(data["station_node"])))


if __name__ == "__main__":
    main()
