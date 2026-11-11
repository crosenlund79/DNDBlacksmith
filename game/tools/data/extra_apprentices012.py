"""Workshop apprentices (iteration 012): authored rules and flavour for Apprentices (scripts/systems/apprentices.gd).
Importing this module (make_data.py imports every extra_*.py) writes data/apprentices.json; it can also be run on
its own: python3 tools/data/extra_apprentices012.py. Read in game with DB.extra("apprentices").

Numbers that shape play live here: the unlock gate, staff limits, the shift, trait effects, rank thresholds and
what each rank may do, minutes per operation, the quality model, mistakes and surprises, station wear,
mentoring, loyalty and independence. The engine falls back to the same defaults if a key is missing.
"""
import json
import os

D = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "data")

DATA = {
    "_doc": "Workshop apprentices — see tools/data/extra_apprentices012.py. Rules read by Apprentices (apprentices.gd).",
    # the smith can take apprentices once he can teach: a seasoned hand (smithing 6) OR the first room bought next door
    "unlock": {"smithing": 6, "units": 2,
               "text": "Take apprentices once you can teach: Smithing 6, or after buying the first room next door."},
    # 1 place, +1 per further owned workshop room, never more than 4
    "staff": {"base": 1, "per_workshop_room": 1, "max": 4},
    "shift": {"start": 8, "end": 18, "break_start": 12, "break_end": 13},
    "applicants": {"min": 1, "max": 3, "fee_days": 5, "base_wage": 3},
    "skills": ["smithing", "runecraft", "alchemy", "enchanted_stitching", "arcane_metalwork"],
    "traits": {
        "careful": {"name": "Careful", "good": True, "desc": "Steadier work: fewer mistakes, less variance", "sd": 0.75, "mistake": 0.6, "quality": 2.0},
        "quick_hands": {"name": "Quick hands", "good": True, "desc": "Works a fifth faster", "speed": 1.2},
        "eager": {"name": "Eager learner", "good": True, "desc": "Learns 30% faster", "xp": 1.3},
        "steady": {"name": "Steady", "good": True, "desc": "Rarely flustered; loyal", "mistake": 0.8, "loyalty": 6},
        "gifted": {"name": "Gifted eye", "good": True, "desc": "A little better craftsmanship; more happy accidents", "quality": 3.0, "surprise": 1.6},
        "absent": {"name": "Absent-minded", "good": False, "desc": "Forgets the fire: more mistakes", "mistake": 1.7},
        "heavy": {"name": "Heavy-handed", "good": False, "desc": "Rougher work, wider swings", "sd": 1.35, "quality": -3.0},
        "proud": {"name": "Proud", "good": False, "desc": "Learns slowly from correction; mentoring helps less", "xp": 0.85, "mentor": 0.6},
        "slow": {"name": "Slow", "good": False, "desc": "Works a fifth slower", "speed": 0.8},
        "fickle": {"name": "Fickle", "good": False, "desc": "Loyalty drifts more easily", "loyalty": -8},
    },
    # rank thresholds: works completed AND level in their best crafting skill; what each rank may do
    "ranks": [
        {"id": "novice", "name": "Novice", "works": 0, "skill": 0, "max_difficulty": 2, "equipment": False,
         "disciplines": ["classic", "stitching", "alchemy"], "trained_only": False,
         "quality": -8.0, "speed": 0.65, "ceiling": 88.0, "raise": 0,
         "desc": "Repairs, preparing materials and keeping the stations in order."},
        {"id": "apprentice", "name": "Apprentice", "works": 8, "skill": 3, "max_difficulty": 4, "equipment": True,
         "disciplines": ["classic", "stitching", "alchemy"], "trained_only": False,
         "quality": 0.0, "speed": 0.85, "ceiling": 98.0, "raise": 1,
         "desc": "Common classic smithing and stitching: plain weapons, armour, garments."},
        {"id": "journeyman", "name": "Journeyman", "works": 30, "skill": 5, "max_difficulty": 6, "equipment": True,
         "disciplines": ["classic", "stitching", "alchemy", "runecraft"], "trained_only": True,
         "quality": 6.0, "speed": 1.0, "ceiling": 104.0, "raise": 2,
         "desc": "Other disciplines they have trained (runes, potions) and steel work."},
        # The Living Workshop B2: a master's reach covers the hardest Design in the catalogue (Adamantine Warplate,
        # difficulty 11 with its material). At 10 nobody could ever make it once the smith's arcane work stopped at the
        # basic level (B1) — a progression deadlock (tests: t_lw_knowledge reachability).
        {"id": "master", "name": "Master", "works": 70, "skill": 8, "max_difficulty": 12, "equipment": True,
         "disciplines": ["classic", "stitching", "alchemy", "runecraft", "arcane"], "trained_only": True,
         "quality": 7.0, "speed": 1.15, "ceiling": 112.0, "raise": 3, "min_rarity": True,
         "desc": "Hard work, arcane metal they have trained in, and legendary-grade Designs."},
    ],
    # a discipline counts as "trained" once the apprentice reaches this level in its skill
    "trained_level": 2,
    # skill vs difficulty: an apprentice may attempt a recipe up to this many levels above their skill
    "reach": 1,
    "categories": {
        "blades": "blades", "axes": "axes and maces", "armour": "armour", "shields": "shields", "bows": "bows",
        "garments": "garments", "potions": "potions and oils", "runes": "runes", "ingots": "ingots and charged metal",
        "cloth": "leather and cloth", "jewellery": "jewellery", "repairs": "repairs", "upkeep": "station upkeep",
    },
    "specialty": {"works": 12, "share": 0.4, "quality": 5.0, "speed": 1.15, "xp": 1.1},
    # minutes for one operation = (base + per_check × checks) ÷ speed factors
    "time": {"op_base": 30.0, "per_check": 12.0, "min_op": 10.0, "level_speed": 0.04,
             "repair_station": "grinding_wheel", "repair_minutes": 50.0, "maintain_per_point": 0.7, "maintain_min": 15.0},
    # expected craftsmanship of one operation; seeded normal variance per operation
    "quality": {"base": 74.0, "per_level": 3.0, "gap_floor": -6, "gap_ceiling": 6, "sd": 8.0, "skill_bonus": 0.4,
                "supervised": 3.0, "worn_station": -6.0, "floor": 10.0, "op_cap": 118.0},
    "mistakes": {"chance": 0.07, "per_gap": 0.02, "rough": -22.0, "time": 0.25, "cheap_value": 12,
                 "kinds": ["rough", "waste", "time"]},
    "surprise": {"chance": 0.04, "bonus": [6.0, 12.0]},
    "wear": {"per_op": 2.5, "worn": 45.0, "slow": 0.8},
    "xp": {"mult": 1.0, "routine_gap": 4, "routine_mult": 0.35, "hard_mult": 1.4, "repair": 10, "maintain": 4, "per_op": 2},
    "mentor": {"minutes": 60, "xp": 45, "loyalty": 4.0},
    "loyalty": {"start": 60.0, "unpaid": -12.0, "paid": 0.5, "leave_below": 15.0, "notice_days": 3, "work_day": 0.2},
    "independence": {"min_days": 60, "loyalty": 75.0, "works": 60, "notice_days": 7, "chance": 0.08,
                     "stay_raise": 2, "stay_loyalty": 10.0, "stay_cooldown": 120},
    "alumni": {"sell_chance": 0.35, "place": "%s's workshop, Brindlewick"},
    "lines": {
        "hired": ["%s ties on a leather apron and asks where the brooms are kept.",
                  "%s arrives with a bundle of tools wrapped in oilcloth and a nervous grin."],
        "rough": ["%s overheated the billet: the %s came out rough.",
                  "%s lost the rhythm at the %s; the work came out rough."],
        "waste": ["%s spoiled a unit of %s and had to fetch another from the stores.",
                  "%s dropped %s in the quench and wasted it."],
        "time": ["%s had to start the %s over — time lost, nothing worse.",
                 "%s misjudged the heat and redid a step at the %s."],
        "surprise": ["%s found the grain of the metal just right: the %s came out better than expected.",
                     "Something clicked for %s today — the %s is the best they have made."],
        "rank": ["%s is now a %s of the Ironhand forge.", "Brannoc names %s %s; they grin all afternoon."],
        "specialty": ["%s has found their calling: %s.", "Everyone in Brindlewick now says %s is the one for %s."],
        "mentor": ["Brannoc stood beside %s at the %s for an hour, showing how the hammer should fall.",
                   "An hour with %s: the smith corrects grip, stance and patience."],
        "recognise": ["%s looks up from the bench: \"That's my %s — I made it on day %d!\"",
                      "%s recognises the %s at once: \"My mark, see? Day %d. It came back.\""],
        "leave_notice": ["%s has not been paid and says they will leave in %d days unless it is put right."],
        "left_unpaid": ["%s packed their tools and left the forge: the wages never came."],
        "independence": ["%s asks to talk after the shift: they would like to open a workshop of their own in %d days."],
        "bless": ["%s leaves with your blessing to open a workshop of their own. The Ironhand mark will be missed on their work — theirs now carries their own."],
        "stay": ["%s stays on, with a raise and a handshake. \"Not yet, then. Not for a long while.\""],
        "alumni_sale": ["%s sold %s a %s from their own workshop."],
    },
}


def write():
    with open(os.path.join(D, "apprentices.json"), "w") as f:
        json.dump(DATA, f, indent=1, ensure_ascii=False)


try:
    write()
except Exception as _e:  # never break make_data.py because of this catalogue
    print("extra_apprentices012: apprentices.json not written:", _e)

if __name__ == "__main__":
    write()
    print("wrote data/apprentices.json")
