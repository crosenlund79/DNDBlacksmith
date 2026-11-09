"""The Living Realm (milestone 5) — major contracts: patrons, contract templates and the project bench's numbers.
Writes game/data/contracts.json (read by scripts/systems/contracts.gd through DB.extra("contracts")).
Run: python3 tools/data/make_contracts.py

Patrons come in tiers; a tier opens only through real accomplishments (Contracts.standing() reads reputation,
contracts delivered well, Hall of Fame plaques, Epic pieces and the forge's renown) — never a bare threshold.
A template's lines name RECIPES: materials, stations and difficulty come from the recipe data, the hours per unit
from its difficulty (0.6 h + 0.4 h per difficulty step, quartered)."""
import json
import os

D = os.path.join(os.path.dirname(__file__), "..", "..", "data")


def L(recipe, n):
    return {"recipe": recipe, "n": n}


def MP(defs, min_q, label):
    """The one individually crafted masterpiece inside the order (made at the stations by the smith himself)."""
    return {"defs": defs, "min_q": min_q, "label": label}


PATRONS = {
    "odo_varrick": {"name": "Odo Varrick", "title": "wool merchant of Highmarsh", "kind": "merchant", "tier": 1, "seal": "merchant",
                    "voice": "A merchant pays for what lasts the road."},
    "brindlewick_muster": {"name": "Reeve Tamsin Hale", "title": "for the Brindlewick muster", "kind": "militia", "tier": 1, "seal": "militia",
                           "voice": "The village looks after its own."},
    "highmarsh_watch": {"name": "Captain Hedda Rourke", "title": "of the Highmarsh Watch", "kind": "watch", "tier": 2, "seal": "watch",
                        "voice": "The watch remembers who armed it."},
    "merchants_guild": {"name": "Guildmaster Corvin Ashby", "title": "of the Merchants' Guild", "kind": "guild", "tier": 2, "seal": "guild",
                        "voice": "The Guild buys only matched work."},
    "warden_aldwin": {"name": "Lord Aldwin Tarrow", "title": "Warden of the Western Marches", "kind": "leader", "tier": 3, "seal": "leader",
                      "voice": "A warden's men are only as good as their steel."},
    "royal_household": {"name": "The Royal Household", "title": "by the hand of Queen Ysolde's steward", "kind": "royal", "tier": 4, "seal": "royal",
                        "voice": "The Crown does not ask twice."},
}

TEMPLATES = [
    {"id": "drovers_kit", "patron": "odo_varrick", "title": "Hatchets and bucklers for the drovers' road",
     "text": "Odo Varrick's drovers take the wool down the marsh road every spring, and the road has teeth. He wants twelve iron hatchets and eight iron bucklers, plain and sound.",
     "lines": [L("iron_hatchet", 12), L("iron_buckler", 8)], "min_q": 62, "days": 7, "pay": 560, "advance": 0.3, "rep": 3,
     "crate": {"ingot_iron": 10, "leather_cured": 8, "coal": 6}, "rare": {}, "masterpiece": None},
    {"id": "muster_helms", "patron": "brindlewick_muster", "title": "Helms and shields for the village muster",
     "text": "Since the wolves came down from the Greywood the reeve keeps a muster of farmhands. She asks for ten iron helms and six round shields for them.",
     "lines": [L("iron_helm", 10), L("round_shield", 6)], "min_q": 60, "days": 8, "pay": 620, "advance": 0.3, "rep": 4,
     "crate": {"ingot_iron": 8, "leather_cured": 10}, "rare": {}, "masterpiece": None},
    {"id": "watch_arms", "patron": "highmarsh_watch", "title": "Forty blades and twenty round shields for the Highmarsh Watch",
     "text": "The Highmarsh Watch is doubling its patrols on the causeway. Captain Rourke wants forty iron shortswords and twenty round shields — and a captain's longsword for herself, worthy of the post.",
     "lines": [L("iron_shortsword", 40), L("round_shield", 20)], "min_q": 70, "days": 14, "pay": 2600, "advance": 0.25, "rep": 6,
     "crate": {"ingot_iron": 40, "leather_cured": 40}, "rare": {},
     "masterpiece": MP(["sword_iron", "sword_steel"], 95, "a captain's longsword")},
    {"id": "guild_blades", "patron": "merchants_guild", "title": "A matched set of twelve steel blades for the Merchants' Guild",
     "text": "The Guild arms its caravan masters with matched steel, silver-chased at the hilt. Twelve steel shortswords of one weight and one temper — and a rapier for the Guildmaster's own hip.",
     "lines": [L("steel_shortsword", 12)], "min_q": 84, "days": 10, "pay": 2700, "advance": 0.3, "rep": 6,
     "crate": {"ingot_steel": 8, "leather_cured": 12}, "rare": {"ore_silver": 6},
     "masterpiece": MP(["sword_rapier"], 100, "the Guildmaster's rapier")},
    {"id": "captains_company", "patron": "warden_aldwin", "title": "Armour for a captain's company",
     "text": "Lord Aldwin is raising a company to hold the western fords. Ten coats of iron chainmail and ten iron helms, garnet-pinned with the Warden's badge — and a steel cuirass for their captain.",
     "lines": [L("iron_chainmail", 10), L("iron_helm", 10)], "min_q": 84, "days": 12, "pay": 3900, "advance": 0.3, "rep": 8,
     "crate": {"ingot_iron": 30, "leather_cured": 14}, "rare": {"gem_garnet": 2},
     "masterpiece": MP(["cuirass_steel"], 100, "the captain's steel cuirass")},
    {"id": "queens_guard", "patron": "royal_household", "title": "Ceremonial arms for the Queen's Guard",
     "text": "Word of the Ironhand forge has reached the court. The Royal Household commissions twelve steel longswords and twelve kite shields for the Queen's Guard, silver-chased and garnet-set — and a sword of state to be carried before the Queen.",
     "lines": [L("steel_longsword", 12), L("kite_shield", 12)], "min_q": 94, "days": 18, "pay": 9500, "advance": 0.3, "rep": 12,
     "crate": {"ingot_steel": 36, "leather_cured": 24}, "rare": {"ore_silver": 8, "gem_garnet": 4},
     "masterpiece": MP(["sword_great", "sword_bastard"], 110, "the Queen's sword of state")},
]

CONFIG = {
    "hour_minutes": 60,          # one block-hour at the bench is an hour of game time
    "blocks": [1, 2, 4],         # selectable blocks of hours
    "fatigue_per_hour": 4.0,     # on top of the ordinary waking hour (Vitality)
    "exhausted": 92.0,           # the smith will not start a block this tired
    "offer_every": 6,            # days between letters at most once …
    "first_day": 4,              # … and never before this day
    "offer_days": 5,             # a letter waits this many days for an answer
    "max_active": 2,
    "grace": 5,                  # days after the deadline before the patron gives up
    "late_per_day": 0.1,         # pay lost per late day (to at least half)
    "poor_factor": 0.6,
    "excellent_factor": 1.15,
    "excellent_margin": 12,      # craftsmanship above the minimum for an excellent result
    "missing_masterpiece": 0.85,
    "rare_at": 0.5,              # rare materials are needed from this share of the units on
    "smith_quality": {"base": 80.0, "per_gap": 3.5, "per_level": 0.5, "sd": 5.0, "tired": 40.0},
    "speed_per_gap": 0.04,
    "xp_per_hour": 6,
    "apprentice_hours": [4, 8, 16],
}

if __name__ == "__main__":
    with open(os.path.join(D, "contracts.json"), "w") as f:
        json.dump({"patrons": PATRONS, "templates": TEMPLATES, "config": CONFIG}, f, indent=1, ensure_ascii=False)
    print("contracts.json:", len(PATRONS), "patrons,", len(TEMPLATES), "templates")
