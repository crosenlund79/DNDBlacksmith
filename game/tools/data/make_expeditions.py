"""Generates game/data/expeditions.json — the adventurers' world: region maps (points of interest on a
1280x720 parchment map), enemies, class archetypes, adventurer relationships and difficulty rules.
Run: python3 tools/data/make_expeditions.py

Regions keep the existing destination ids (destinations.json): Whisperwood (forest ruins), Ironroot Mine
(the broken quarry: bandits, rare ores, salvage), Highmarsh Road (trade road), Barrow Fields (the old
crypt: undead, traps, relics) and Deep Ironroot (the ashen depths: advanced foes, magical materials).
Node kinds: entry, path, encounter, trap, chest, resource, shrine, puzzle, traveller, boss.
"""
import json, os
D = os.path.join(os.path.dirname(__file__), "..", "..", "data")


def node(id, name, kind, x, y, links, enemies=None, dc=12, loot="", tier=1, desc=""):
    return dict(id=id, name=name, kind=kind, x=x, y=y, links=links, enemies=enemies or [], dc=dc, loot=loot, tier=tier, desc=desc)


def enemy(id, name, kind, hp, atk, dmg, ac, xp, weak="", resist="", power=10, desc=""):
    return dict(id=id, name=name, kind=kind, hp=hp, atk=atk, dmg=dmg, ac=ac, xp=xp, weak=weak, resist=resist, power=power, desc=desc)


ENEMIES = [
    enemy("wolf", "Grey Wolf", "beast", 11, 3, "1d6+1", 12, 12, weak="fire", power=8, desc="Hunts in packs; goes for the slowest."),
    enemy("wolf_alpha", "The Whisperwood Alpha", "beast", 42, 6, "2d6+3", 14, 90, weak="fire", power=40, desc="A scarred grey giant that has led the pack for a decade."),
    enemy("boar", "Tusked Boar", "beast", 18, 4, "1d8+2", 12, 18, power=12),
    enemy("spider", "Cave Spider", "beast", 9, 4, "1d6", 13, 10, weak="fire", power=8, desc="Venom slows its prey."),
    enemy("brood_mother", "The Brood Mother", "beast", 48, 6, "2d6+2", 14, 100, weak="fire", power=44),
    enemy("goblin", "Tunnel Goblin", "humanoid", 8, 3, "1d6", 13, 8, power=7),
    enemy("bandit", "Road Bandit", "humanoid", 14, 4, "1d8+1", 13, 14, power=11),
    enemy("bandit_captain", "Captain Vell of the Toll Bridge", "humanoid", 40, 6, "2d6+2", 15, 90, power=40),
    enemy("bog_wraith", "Bog Wraith", "spirit", 20, 5, "1d8+2", 14, 30, weak="magic", resist="physical", power=20, desc="Blades pass through it; magic does not."),
    enemy("skeleton", "Skeleton Warden", "undead", 13, 4, "1d8", 13, 14, weak="fire", resist="frost", power=11),
    enemy("wight", "Barrow Wight", "undead", 24, 5, "1d10+2", 14, 34, weak="fire", resist="frost", power=22, desc="Its touch drains warmth; fire undoes it."),
    enemy("barrow_lord", "The Barrow Wight-Lord", "undead", 62, 7, "2d8+3", 16, 160, weak="fire", resist="frost", power=58),
    enemy("golem", "Stone Golem", "construct", 50, 6, "2d8+2", 17, 110, weak="frost", resist="fire", power=48, desc="Cracks when frozen."),
    enemy("shadow", "Shadow Crawler", "spirit", 22, 6, "1d10+2", 15, 40, weak="fire", resist="physical", power=26),
    # trade worker: monsters whose hides reach the forge as offers at the shop counter
    enemy("bear", "Whisperwood Cave Bear", "beast", 30, 5, "1d10+3", 13, 45, weak="fire", power=26, desc="Slow to anger, impossible to stop once it is."),
    enemy("troll", "Marsh Troll", "giant", 38, 5, "2d6+2", 13, 60, weak="fire", power=32, desc="Its wounds close as you watch; fire keeps them open."),
    enemy("wyvern", "Barrow Wyvern", "beast", 34, 6, "1d10+3", 14, 55, weak="frost", power=30, desc="Roosts on the high mounds; its tail-sting burns."),
    enemy("revenant", "The Dwarf-King's Revenant", "undead", 80, 8, "2d10+4", 17, 220, weak="fire", resist="frost", power=74),
    # world worker (iteration 011): the new sites' foes, their unique masters and the weaker successors that
    # may move into a cleared lair much later (a slain unique boss never comes back)
    enemy("bandit_archer", "Hold Crossbowman", "humanoid", 12, 5, "1d8+1", 13, 16, power=13, desc="Shoots from behind the palisade, then runs."),
    enemy("war_hound", "Hold War-hound", "beast", 12, 4, "1d6+2", 12, 12, weak="fire", power=10, desc="Spiked collar, cropped ears, no fear."),
    enemy("black_maud", "Black Maud, Warlord of Raven's Hold", "humanoid", 54, 7, "2d6+3", 16, 140, power=52, desc="She took the Hold from the king's men and has kept it eleven winters."),
    enemy("drowned", "Drowned Acolyte", "undead", 16, 4, "1d8+1", 12, 18, weak="fire", resist="frost", power=13, desc="Temple servants who never left when the waters came."),
    enemy("temple_serpent", "Temple Serpent", "beast", 26, 5, "1d10+2", 14, 36, weak="frost", power=24, desc="Thick as a man's waist; it guards the pool it was fed in."),
    enemy("drowned_oracle", "The Drowned Oracle", "spirit", 58, 7, "2d8+2", 15, 150, weak="magic", power=54, desc="She still answers questions. Nobody likes the answers."),
    enemy("harpy", "Crag Harpy", "beast", 14, 5, "1d6+2", 14, 18, weak="fire", power=13, desc="Shrieks first, dives second."),
    enemy("drakeling", "Ashen Drakeling", "beast", 18, 5, "1d8+2", 14, 26, weak="frost", resist="fire", power=18, desc="A drake's whelp: small, hot-blooded and mean."),
    enemy("cinderjaw", "Cinderjaw, the Old Drake", "beast", 96, 8, "2d10+4", 17, 280, weak="frost", resist="fire", power=92, desc="Older than the village. Its breath melts the snow on the crag."),
    enemy("young_alpha", "Greyfang, the Young Alpha", "beast", 30, 5, "2d6+1", 13, 60, weak="fire", power=28, desc="The old Alpha's get, grown into the hollow."),
    enemy("brood_daughter", "A Brood-Daughter", "beast", 32, 5, "2d6", 13, 65, weak="fire", power=30, desc="One of the Brood Mother's eggs that did not burn."),
    enemy("toll_sergeant", "Sergeant Hask of the Toll", "humanoid", 30, 5, "1d10+2", 14, 60, power=28, desc="Vell's old sergeant, collecting the toll again."),
    enemy("wight_steward", "The Wight-Steward", "undead", 42, 6, "2d6+2", 15, 100, weak="fire", resist="frost", power=40, desc="The Wight-Lord's servant, keeping the barrow for a master who will not return."),
    enemy("hollow_warden", "The Hollow Warden", "construct", 55, 7, "2d8+2", 16, 150, weak="frost", resist="fire", power=52, desc="A dwarf-built guardian that woke when its king fell."),
    enemy("corvin", "Corvin Blackfeather", "humanoid", 36, 6, "1d10+3", 15, 80, power=36, desc="Maud's lieutenant, regrouping what is left of her band."),
    enemy("oracle_echo", "The Oracle's Echo", "spirit", 38, 6, "2d6+1", 14, 90, weak="magic", power=36, desc="What is left of the Oracle's voice in the water."),
    enemy("smoulderwing", "Smoulderwing, a Young Drake", "beast", 52, 7, "2d8+2", 16, 150, weak="frost", resist="fire", power=50, desc="Cinderjaw's last whelp, grown into the lair."),
]

# 1280 x 720 parchment map coordinates; the village gate is the first node (entry)
REGIONS = {
    "whisperwood": {"name": "Whisperwood", "travel_h": [2, 3], "theme": "forest ruins, beasts, herbs",
        "nodes": [
            node("gate", "The western road", "entry", 90, 600, ["trail"]),
            node("trail", "Deer trail", "path", 300, 520, ["glade", "den"], dc=11),
            node("glade", "Herb glade", "resource", 340, 280, ["tower", "bloodroot"], loot="forest", desc="Moonwort and emberleaf under the old oaks."),
            node("bloodroot", "Bloodroot hollow", "resource", 520, 110, ["tower"], loot="herbs_wild", desc="Bloodroot, frostcap and silverleaf in the damp shade of the hollow."),
            node("den", "Wolf den", "encounter", 560, 470, ["tower", "shrine", "bear_cave"], enemies=[["wolf", 3]]),
            node("bear_cave", "Bear cave", "encounter", 720, 640, ["shrine"], enemies=[["bear", 1]], loot="beast_bear", tier=2, desc="Bones at the mouth, and a smell like wet dog and old blood."),
            node("tower", "Ruined watchtower", "chest", 700, 230, ["shrine", "hollow"], dc=12, loot="forest", tier=2),
            node("shrine", "Mossy wayshrine", "shrine", 880, 520, ["hollow"]),
            node("traveller", "A wounded trapper", "traveller", 980, 360, ["hollow"]),
            node("hollow", "Alpha's hollow", "boss", 1140, 210, [], enemies=[["wolf_alpha", 1], ["wolf", 2]], loot="forest", tier=3),
        ]},
    "ironroot_mine": {"name": "Ironroot Mine", "travel_h": [1, 2], "theme": "broken quarry, goblins, ore, salvage",
        "nodes": [
            node("gate", "The north track", "entry", 110, 620, ["mouth"]),
            node("mouth", "Quarry mouth", "path", 280, 500, ["vein", "camp"], dc=10),
            node("vein", "Exposed ore vein", "resource", 400, 260, ["gallery"], loot="mine"),
            node("camp", "Goblin camp", "encounter", 600, 520, ["gallery", "strongbox"], enemies=[["goblin", 4]]),
            node("gallery", "Collapsed gallery", "trap", 640, 250, ["strongbox", "nest"], dc=13),
            node("strongbox", "Foreman's strongbox", "chest", 860, 460, ["nest"], dc=13, loot="mine", tier=2),
            node("nest", "Spider nest", "boss", 1120, 300, [], enemies=[["brood_mother", 1], ["spider", 2]], loot="mine", tier=3),
        ]},
    "highmarsh_road": {"name": "Highmarsh Road", "travel_h": [2, 3], "theme": "trade road, bandits, bog",
        "nodes": [
            node("gate", "The eastern gate", "entry", 90, 360, ["mile"]),
            node("mile", "Mile-stone camp", "path", 280, 360, ["caravan", "bridge"], dc=10),
            node("caravan", "Wrecked caravan", "traveller", 420, 170, ["bog"], loot="trade"),
            node("bridge", "The toll bridge", "encounter", 520, 520, ["bog", "cache", "troll_ford"], enemies=[["bandit", 3]]),
            node("troll_ford", "Troll's ford", "encounter", 690, 650, ["cache"], enemies=[["troll", 1]], loot="beast_troll", tier=2, desc="The ford nobody uses; the troll under it eats the ones who do."),
            node("bog", "Bog crossing", "encounter", 760, 280, ["cache", "captain"], enemies=[["bog_wraith", 1]]),
            node("cache", "Smugglers' cache", "chest", 860, 560, ["captain"], dc=14, loot="trade", tier=2),
            node("captain", "Vell's hideout", "boss", 1150, 380, [], enemies=[["bandit_captain", 1], ["bandit", 2]], loot="trade", tier=3),
        ]},
    "barrow_fields": {"name": "Barrow Fields", "travel_h": [2, 3], "theme": "the old crypt: undead, traps, relics",
        "nodes": [
            node("gate", "The south road", "entry", 640, 660, ["rows"]),
            node("rows", "Grave rows", "encounter", 640, 500, ["sarcophagus", "door"], enemies=[["skeleton", 3]]),
            node("sarcophagus", "Trapped sarcophagus", "trap", 360, 420, ["ossuary"], dc=14, loot="barrow", tier=2),
            node("door", "The rune door", "puzzle", 900, 420, ["vault", "roost"], dc=14),
            node("roost", "Wyvern roost", "encounter", 1140, 380, ["vault"], enemies=[["wyvern", 1]], loot="beast_wyvern", tier=2, desc="A wyvern nests on the tallest mound among stripped bones."),
            node("ossuary", "Ossuary", "encounter", 330, 220, ["lord"], enemies=[["wight", 2]]),
            node("vault", "Relic vault", "chest", 960, 200, ["lord"], dc=15, loot="barrow", tier=3),
            node("lord", "The Wight-Lord's barrow", "boss", 640, 120, [], enemies=[["barrow_lord", 1], ["skeleton", 2]], loot="barrow", tier=3),
        ]},
    "deep_ironroot": {"name": "Deep Ironroot", "travel_h": [3, 4], "theme": "ashen depths: golems, shadows, starstone",
        "nodes": [
            node("gate", "The deep stair", "entry", 120, 120, ["crystal"]),
            node("crystal", "Crystal cavern", "resource", 330, 230, ["forge", "rift"], loot="deep_mine", tier=2),
            node("forge", "The golem forge", "encounter", 560, 140, ["hall"], enemies=[["golem", 1]]),
            node("rift", "Shadow rift", "encounter", 520, 420, ["seam", "hall", "warren"], enemies=[["shadow", 2]]),
            node("warren", "Troll warren", "encounter", 790, 330, ["hall"], enemies=[["troll", 1]], loot="beast_deep", tier=3, desc="Cave trolls den in the old smelting halls among hides and ore."),
            node("seam", "Adamantine seam", "resource", 800, 560, ["hall"], loot="deep_mine", tier=3),
            node("hall", "The Dwarf-King's hall", "boss", 1080, 300, [], enemies=[["revenant", 1], ["shadow", 1]], loot="deep_boss", tier=3),
        ]},
    # world worker (iteration 011): sites the adventurers discover
    "ravens_hold": {"name": "Raven's Hold", "travel_h": [3, 4], "theme": "bandit stronghold: palisades, hounds, plunder",
        "nodes": [
            node("gate", "The goat track", "entry", 100, 620, ["scree"]),
            node("scree", "Scree slope", "path", 290, 520, ["kennels", "lookout"], dc=11),
            node("lookout", "Ruined lookout", "chest", 330, 250, ["wall"], dc=13, loot="trade", tier=2, desc="An old royal watch-post; the bandits stash their take in it."),
            node("kennels", "The kennels", "encounter", 560, 560, ["wall", "storehouse"], enemies=[["war_hound", 3]]),
            node("wall", "The broken wall", "encounter", 620, 290, ["yard"], enemies=[["bandit_archer", 2], ["bandit", 1]], tier=2),
            node("storehouse", "Plunder store", "chest", 860, 590, ["yard"], dc=14, loot="reward", tier=2, desc="Barrels, bolts of cloth and a caravan's worth of steel."),
            node("yard", "The muster yard", "trap", 880, 380, ["keep"], dc=14, desc="Caltrops in the mud and a tripwire bell."),
            node("keep", "Black Maud's hall", "boss", 1130, 260, [], enemies=[["black_maud", 1], ["bandit_archer", 1], ["bandit", 1]], loot="reward", tier=3),
        ]},
    "sunken_temple": {"name": "The Sunken Temple", "travel_h": [3, 4], "theme": "a drowned ruin in the marsh: the dead, serpents, relics",
        "nodes": [
            node("gate", "The reed path", "entry", 110, 360, ["causeway"]),
            node("causeway", "Broken causeway", "path", 300, 380, ["pool", "court", "lotus"], dc=12),
            node("pool", "Silted shrine", "shrine", 330, 150, ["court"]),
            node("lotus", "Lotus beds", "resource", 430, 600, ["serpent"], loot="herbs_wild", desc="Pale lotus and bloodroot grow in the warm temple water."),
            node("court", "Flooded court", "encounter", 580, 340, ["serpent", "door"], enemies=[["drowned", 3]]),
            node("serpent", "Serpent pool", "encounter", 780, 590, ["sanctum"], enemies=[["temple_serpent", 1]], loot="gift", tier=2),
            node("door", "The tide door", "puzzle", 820, 170, ["sanctum"], dc=15),
            node("sanctum", "The Oracle's sanctum", "boss", 1120, 350, [], enemies=[["drowned_oracle", 1], ["drowned", 2]], loot="barrow", tier=3),
        ]},
    "drakes_crag": {"name": "Drake's Crag", "travel_h": [4, 5], "theme": "a drake's mountain: harpies, drakelings, a hoard",
        "nodes": [
            node("gate", "The shepherd's climb", "entry", 640, 660, ["ledge"]),
            node("ledge", "Windy ledge", "path", 600, 520, ["obsidian", "nests"], dc=12),
            node("obsidian", "Obsidian scree", "resource", 320, 470, ["bones"], loot="mine", tier=2, desc="Glassy black stone and ore cracked out by the drake's heat."),
            node("nests", "Harpy nests", "encounter", 900, 520, ["bones", "vents"], enemies=[["harpy", 3]]),
            node("bones", "Field of bones", "chest", 360, 220, ["hoard"], dc=13, loot="barrow", tier=2, desc="Knights and sheep alike; some of the knights still have their purses."),
            node("vents", "Ash vents", "encounter", 960, 270, ["hoard"], enemies=[["drakeling", 2]], loot="beast_wyvern", tier=3),
            node("hoard", "Cinderjaw's lair", "boss", 650, 120, [], enemies=[["cinderjaw", 1], ["drakeling", 1]], loot="deep_boss", tier=3),
        ]},
}

# ------------------------------------------------------------------ world sites (iteration 011)
# Every region is a persistent site on the world map (Game.state["world_sites"] keeps its state).
#   type: site icon on the world map; pos: on the 1600x1000 world map (Brindlewick at 800,520)
#   known: known from the start; gate: a world flag that reveals it instead (deep_ironroot: the delve map)
#   near: regions whose explorers may stumble on it; boss: the boss node (its first enemy is the unique boss)
#   successor: what may move into the cleared lair, after successor_days; growth: threat gained per day while
#   the master lives; likes: classes and traits drawn to it; cond: condition lines; folk: who else lives there
SITES = {
    "whisperwood": dict(type="forest", pos=[400, 470], known=True, near=[], boss="hollow",
        successor=[["young_alpha", 1], ["wolf", 2]], successor_days=[30, 44], growth=0.05,
        likes=dict(cls=["Ranger", "Barbarian"], trait=["cautious"]),
        desc="Old oak forest west of the village: herb glades, a ruined watchtower and the hollow where the Alpha dens.",
        folk=["herb-wives and trappers", "a hermit at the wayshrine"],
        cond=dict(growing="The wolf packs are growing bold.", regroup="Wolves howl again along the deer trail.",
                  cleared="The Alpha's hollow lies empty; the packs scatter without a leader.", successor="A young alpha has taken the hollow.")),
    "ironroot_mine": dict(type="mine", pos=[770, 270], known=True, near=[], boss="nest",
        successor=[["brood_daughter", 1], ["spider", 2]], successor_days=[26, 40], growth=0.07,
        likes=dict(cls=["Fighter", "Barbarian"], trait=["greedy", "steady"]),
        desc="The broken quarry north of the village: dwarf-cut galleries, goblins, ore — and a spider nest in the deep end.",
        folk=["goblin scavengers", "old miners who still come for coal"],
        cond=dict(growing="The spider brood is growing.", regroup="Goblins have crept back into the camp.",
                  cleared="The nest was burned out; only husks hang in the gallery.", successor="A brood-daughter spins in the old nest.")),
    "highmarsh_road": dict(type="road", pos=[1190, 500], known=True, near=[], boss="captain",
        successor=[["toll_sergeant", 1], ["bandit", 2]], successor_days=[22, 34], growth=0.06,
        likes=dict(cls=["Rogue", "Bard"], trait=["greedy", "brave"]),
        desc="The trade road east to Highmarsh: a toll bridge, a bog, a troll's ford and Vell's hideout.",
        folk=["carters and pedlars", "the Highmarsh toll-keepers"],
        cond=dict(growing="Bandits are thick on the road; carters travel only in convoys.", regroup="The bandits are regrouping at the toll bridge.",
                  cleared="Vell's hideout stands empty; the carters breathe again.", successor="Vell's old sergeant collects the toll again.")),
    "barrow_fields": dict(type="barrow", pos=[830, 830], known=True, near=[], boss="lord",
        successor=[["wight_steward", 1], ["skeleton", 2]], successor_days=[34, 50], growth=0.05,
        likes=dict(cls=["Cleric", "Paladin", "Wizard"], trait=["devout"]),
        desc="Burial mounds south of the village: grave rows, a rune door, the relic vault and the Wight-Lord's barrow.",
        folk=["a gravedigger's family", "relic-hunters from away"],
        cond=dict(growing="The dead walk in numbers on the grave rows.", regroup="Fresh tracks lead out of the open graves.",
                  cleared="The Wight-Lord's barrow lies broken open and silent.", successor="The crypt was sealed again — something keeps it now.")),
    "deep_ironroot": dict(type="deep", pos=[1010, 150], known=False, gate="delve_map", near=[], boss="hall",
        successor=[["hollow_warden", 1], ["shadow", 1]], successor_days=[40, 60], growth=0.04,
        likes=dict(cls=["Wizard", "Fighter", "Paladin"], trait=["brave", "greedy"]),
        desc="Below the old workings: crystal caverns, the golem forge and the Dwarf-King's hall. Found with the delve map.",
        folk=["nobody living"],
        cond=dict(growing="Shadows crowd the rift.", regroup="The golem forge glows again.",
                  cleared="The Dwarf-King's hall is quiet; his crown-seat stands empty.", successor="A warden of stone walks the Dwarf-King's hall.")),
    "ravens_hold": dict(type="stronghold", pos=[1400, 270], known=False, near=["highmarsh_road"], boss="keep",
        successor=[["corvin", 1], ["bandit", 2]], successor_days=[24, 36], growth=0.08,
        likes=dict(cls=["Rogue", "Fighter"], trait=["greedy", "reckless"]),
        desc="A hillfort on the crags north of the Highmarsh road, taken from the king's men by Black Maud's band.",
        folk=["Black Maud's band", "captives taken on the road"],
        cond=dict(growing="Maud's band grows; new faces at the palisade.", regroup="The bandits are regrouping behind the wall.",
                  cleared="The Hold's hall is empty; ravens sit on the broken gate.", successor="Corvin Blackfeather is regrouping the band in the Hold.")),
    "sunken_temple": dict(type="temple", pos=[330, 790], known=False, near=["whisperwood", "barrow_fields"], boss="sanctum",
        successor=[["oracle_echo", 1], ["drowned", 2]], successor_days=[30, 46], growth=0.05,
        likes=dict(cls=["Cleric", "Wizard", "Bard"], trait=["devout", "cautious"]),
        desc="A drowned temple in the south-western marsh; its court and sanctum stand half under water.",
        folk=["drowned acolytes", "marsh-folk who leave offerings"],
        cond=dict(growing="The drowned rise thicker each night.", regroup="Something stirs in the flooded court again.",
                  cleared="The sanctum water lies still; the Oracle is silent.", successor="An echo of the Oracle whispers in the sanctum.")),
    "drakes_crag": dict(type="crag", pos=[420, 160], known=False, near=["ironroot_mine", "whisperwood"], boss="hoard",
        successor=[["smoulderwing", 1], ["drakeling", 1]], successor_days=[45, 70], growth=0.04,
        likes=dict(cls=["Barbarian", "Paladin", "Fighter"], trait=["brave", "reckless"]),
        desc="A smoking crag in the north-western mountains where an old drake sleeps on a hoard.",
        folk=["harpies", "goatherds who will not go above the treeline"],
        cond=dict(growing="Drakelings hatch in the ash vents.", regroup="Harpies are back on the nests.",
                  cleared="Cinderjaw's lair is cold; its hoard is gone.", successor="A young drake has taken the old lair.")),
}

ARCHETYPES = {
    "Fighter": {"role": "front", "attr": {"str": 3, "dex": 1, "int": 0, "wis": 0, "con": 3}, "hp": 14, "hp_lv": 7, "skills": ["guard", "weapons"], "prefers": ["sword", "axe", "mace"]},
    "Paladin": {"role": "front", "attr": {"str": 3, "dex": 0, "int": 0, "wis": 2, "con": 2}, "hp": 13, "hp_lv": 6, "skills": ["guard", "smite", "faith"], "prefers": ["mace", "sword"]},
    "Barbarian": {"role": "front", "attr": {"str": 4, "dex": 1, "int": -1, "wis": 0, "con": 3}, "hp": 16, "hp_lv": 8, "skills": ["rage", "weapons"], "prefers": ["axe"]},
    "Ranger": {"role": "scout", "attr": {"str": 1, "dex": 3, "int": 0, "wis": 2, "con": 1}, "hp": 10, "hp_lv": 5, "skills": ["scouting", "archery", "survival"], "prefers": ["bow", "dagger"]},
    "Rogue": {"role": "scout", "attr": {"str": 0, "dex": 4, "int": 1, "wis": 0, "con": 1}, "hp": 9, "hp_lv": 5, "skills": ["traps", "locks", "sneak"], "prefers": ["dagger", "sword"]},
    "Wizard": {"role": "caster", "attr": {"str": -1, "dex": 1, "int": 4, "wis": 1, "con": 0}, "hp": 7, "hp_lv": 4, "skills": ["arcana", "firebolt"], "prefers": ["staff", "dagger"]},
    "Cleric": {"role": "healer", "attr": {"str": 1, "dex": 0, "int": 0, "wis": 4, "con": 2}, "hp": 10, "hp_lv": 6, "skills": ["healing", "turn_undead", "faith"], "prefers": ["mace"]},
    "Bard": {"role": "support", "attr": {"str": 0, "dex": 2, "int": 1, "wis": 1, "con": 1}, "hp": 9, "hp_lv": 5, "skills": ["inspire", "lore"], "prefers": ["dagger", "sword"]},
}

# who likes whom (symmetric unless noted): +friend, -rival
RELATIONS = [
    ["sigrun", "garrick", 40], ["mira", "kestra", 35], ["elowen", "tomas", 30], ["pip", "mira", 25], ["pip", "varn", 20],
    ["varn", "garrick", -35], ["kestra", "garrick", -30], ["sigrun", "varn", 15], ["elowen", "pip", 15], ["tomas", "garrick", 25],
]

DIFFICULTY = {
    "apprentice": {"name": "Apprentice", "observe": True, "detail": True, "enemy": 0.8, "death": False, "death_dc": 0,
        "heal_rate": 1.5, "prices": 1.15, "wages": 0.85, "loot": 1.2, "desc": "Forgiving fights and prices; nobody dies — the fallen are carried home. Full live observation."},
    "journeyman": {"name": "Journeyman", "observe": True, "detail": True, "enemy": 1.0, "death": True, "death_dc": 4,
        "heal_rate": 1.0, "prices": 1.0, "wages": 1.0, "loot": 1.0, "desc": "Moderate risks; death is possible but rare. Live observation and detailed inspection."},
    "master": {"name": "Master", "observe": False, "detail": False, "enemy": 1.25, "death": True, "death_dc": 9,
        "heal_rate": 0.75, "prices": 0.9, "wages": 1.15, "loot": 0.85, "desc": "High risk, tight money, real losses. No omniscient observation: you learn what happened when they come home."},
}

RENOWN_TITLES = [[0, "Unknown"], [25, "Local Name"], [70, "Rising Blade"], [140, "Hero of Brindlewick"], [260, "Living Legend"]]

if __name__ == "__main__":
    for rid, r in REGIONS.items():
        ids = {n["id"] for n in r["nodes"]}
        for n in r["nodes"]:
            for l in n["links"]:
                assert l in ids, (rid, n["id"], l)
            for e in n["enemies"]:
                assert e[0] in {x["id"] for x in ENEMIES}, e
    assert set(SITES) == set(REGIONS)
    for sid, si in SITES.items():
        assert si["boss"] in {n["id"] for n in REGIONS[sid]["nodes"]}, sid
        for e in si["successor"]:
            assert e[0] in {x["id"] for x in ENEMIES}, e
    with open(os.path.join(D, "expeditions.json"), "w") as f:
        json.dump({"enemies": ENEMIES, "regions": REGIONS, "archetypes": ARCHETYPES, "relations": RELATIONS,
                   "difficulty": DIFFICULTY, "renown_titles": RENOWN_TITLES, "sites": SITES}, f, indent=1, ensure_ascii=False)
    print("expeditions.json:", len(ENEMIES), "enemies,", len(REGIONS), "regions")
