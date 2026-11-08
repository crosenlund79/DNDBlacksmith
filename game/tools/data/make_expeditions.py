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
    with open(os.path.join(D, "expeditions.json"), "w") as f:
        json.dump({"enemies": ENEMIES, "regions": REGIONS, "archetypes": ARCHETYPES, "relations": RELATIONS,
                   "difficulty": DIFFICULTY, "renown_titles": RENOWN_TITLES}, f, indent=1, ensure_ascii=False)
    print("expeditions.json:", len(ENEMIES), "enemies,", len(REGIONS), "regions")
