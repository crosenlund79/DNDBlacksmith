"""Ironfront — the war-room card game hosted by Barnaby Quill in his basement.

    python3 make_ironfront.py      ->  game/data/ironfront.json

Real Second World War machines and units, which the villagers of Brindlewick take for
fantastical inventions. Plain national roundels and stars only; no political symbols.

Card fields
  id, name, faction (allies|axis|soviet|neutral), type (unit|tactic), row (inf|arm|air; tactics: ""),
  str (units), abilities [{k: ability, n: value, row: target row, group: reinforce group}],
  effect (tactics), rarity (common|uncommon|rare|special), art (silhouette painter id), flavor,
  special=True -> "found only through merchants or exploration" (never in packs or shop singles).
Ability keys: spotter, artillery, barrage, entrench, combined, supply, reinforce, medic, assault, rally, elite.
"""
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "data", "ironfront.json")


def A(k, n=0, row="", group=""):
    d = {"k": k}
    if n:
        d["n"] = n
    if row:
        d["row"] = row
    if group:
        d["group"] = group
    return d


def U(id, name, faction, row, s, rarity, art, flavor, abil=(), group="", special=False):
    d = dict(id=id, name=name, faction=faction, type="unit", row=row, str=s, abilities=list(abil), rarity=rarity,
             art=art, flavor=flavor, group=group or id)
    if special:
        d["special"] = True
    return d


def T(id, name, effect, rarity, art, flavor, special=False, **kw):
    d = dict(id=id, name=name, faction="neutral", type="tactic", row="", str=0, abilities=[], effect=effect,
             rarity=rarity, art=art, flavor=flavor)
    d.update(kw)
    if special:
        d["special"] = True
    return d


CARDS = [
    # ------------------------------------------------------------------ Allies (western front)
    U("rifle_squad", "Rifle Squad", "allies", "inf", 3, "common", "inf_m1",
      "Men in tin bowls who carry thunder-sticks. They sing about girls they left behind."),
    U("tommies", "Tommy Section", "allies", "inf", 4, "common", "inf_brodie",
      "They wear soup plates for hats and stop the war for tea. Nobody laughs twice.",
      [A("reinforce", group="tommies")]),
    U("airborne", "Airborne Paratroopers", "allies", "inf", 4, "common", "inf_para",
      "They step out of the sky beneath silk mushrooms, as if heaven had a back door.",
      [A("reinforce", group="airborne")]),
    U("rangers", "Rangers", "allies", "inf", 6, "uncommon", "inf_m1",
      "Climbed a sea-cliff under fire with ropes and ladders. Asked what was next.",
      [A("assault", 2)]),
    U("commandos", "Commandos", "allies", "inf", 5, "uncommon", "inf_beret",
      "Green berets, blackened faces and very quiet boots.", [A("assault", 3)]),
    U("combat_medic", "Combat Medic", "allies", "inf", 2, "common", "inf_medic",
      "Carries no sword at all, only bandages and a terrible bravery.", [A("medic")]),
    U("forward_observer", "Forward Observer", "allies", "inf", 2, "common", "inf_observer",
      "Squints through a brass far-glass and whispers to a box that answers.", [A("spotter")]),
    U("sherman", "Sherman M4", "allies", "arm", 6, "common", "tank_sherman",
      "Tall as a hay-wain and twice as common. There is always another one.",
      [A("combined", 2)]),
    U("churchill", "Churchill", "allies", "arm", 7, "uncommon", "tank_churchill",
      "Slow as a sermon and armoured like a cathedral door.", [A("entrench")]),
    U("m7_priest", "M7 Priest", "allies", "arm", 5, "uncommon", "spg_priest",
      "Named for its pulpit. Its sermons land three miles away.", [A("artillery", 4, row="inf")]),
    U("jeep", "Willys Jeep", "allies", "arm", 2, "common", "car_jeep",
      "A horseless cart that goes anywhere and brings back everything.", [A("supply")]),
    U("spitfire", "Spitfire Mk IX", "allies", "air", 6, "uncommon", "air_spitfire",
      "Wings shaped like a beech leaf; it sings as it turns.", [A("combined", 2)]),
    U("mustang", "P-51 Mustang", "allies", "air", 7, "rare", "air_mustang",
      "A silver hawk that flies the bombers all the way there and all the way home.",
      [A("rally", 1)]),
    U("dakota", "C-47 Dakota", "allies", "air", 3, "common", "air_dakota",
      "A flying barn. The paratroopers come out of the side door.",
      [A("reinforce", group="airborne")]),
    U("lancaster", "Avro Lancaster", "allies", "air", 8, "rare", "air_lancaster",
      "Four engines roaring like a forge on a windy night.", [A("barrage", 2, row="inf")]),
    # ------------------------------------------------------------------ Axis
    U("grenadiers", "Grenadiers", "axis", "inf", 4, "common", "inf_stahlhelm",
      "Coal-scuttle helmets and greatcoats to the shin.", [A("reinforce", group="grenadiers")]),
    U("fallschirmjager", "Fallschirmjäger", "axis", "inf", 5, "uncommon", "inf_para_axis",
      "Dropped from the clouds, then dug into a mountain monastery and would not leave.",
      [A("entrench")]),
    U("mg42", "MG 42 Team", "axis", "inf", 5, "common", "inf_mg",
      "Sounds like a loom tearing linen. Men call it the bone-saw.", [A("assault", 2)]),
    U("field_surgeon", "Field Surgeon", "axis", "inf", 2, "common", "inf_medic",
      "Stitches faster than a sail-maker.", [A("medic")]),
    U("panzerfaust", "Panzerfaust Troop", "axis", "inf", 3, "common", "inf_tube",
      "A fist on a stick that punches through a castle gate. Once.", [A("artillery", 3, row="arm")]),
    U("panzer_iv", "Panzer IV", "axis", "arm", 5, "common", "tank_p4",
      "The workhorse. Skirts of iron plate hang along its flanks like barding.",
      [A("combined", 2)]),
    U("panther", "Panther", "axis", "arm", 8, "uncommon", "tank_panther",
      "Sloped like a roof in snow country; its long gun reaches the next parish."),
    U("tiger", "Tiger I", "axis", "arm", 10, "rare", "tank_tiger",
      "A steel beetle that breathes thunder. Villagers say it eats bridges.", [A("entrench")]),
    U("stug", "StuG III", "axis", "arm", 5, "common", "spg_stug",
      "A low iron toad with a gun for a tongue, waiting in the hedgerow.", [A("entrench")]),
    U("flak88", "88 mm Flak", "axis", "arm", 6, "uncommon", "gun_88",
      "Built to swat sky-dragons; equally happy to swat iron ones.", [A("artillery", 4, row="air")]),
    U("halftrack", "Sd.Kfz. 251 Half-track", "axis", "arm", 3, "common", "car_halftrack",
      "Wheels at the front, a mill-belt at the back, and a squad in its belly.", [A("supply")]),
    U("bf109", "Messerschmitt Bf 109", "axis", "air", 5, "common", "air_bf109",
      "A narrow grey falcon with square-clipped wings.", [A("combined", 2)]),
    U("stuka", "Ju 87 Stuka", "axis", "air", 5, "uncommon", "air_stuka",
      "Folds its bent wings and falls screaming like a stooping hawk.", [A("artillery", 4, row="arm")]),
    U("ju52", "Ju 52 Transport", "axis", "air", 3, "common", "air_ju52",
      "Corrugated like a washboard, three-engined, patient as a mule.",
      [A("reinforce", group="fallschirmjager")]),
    # ------------------------------------------------------------------ Soviets
    U("rifle_company", "Rifle Company", "soviet", "inf", 3, "common", "inf_ssh",
      "There are always more of them coming over the snow.", [A("reinforce", group="rifle_company")]),
    U("guards", "Guards Rifles", "soviet", "inf", 6, "uncommon", "inf_ssh",
      "Earned the word Guards in the ruins of a city on the Volga.", [A("combined", 2)]),
    U("snipers", "Sniper Pair", "soviet", "inf", 4, "uncommon", "inf_sniper",
      "Two patient shadows and a rifle with a glass eye.", [A("assault", 3)]),
    U("field_nurse", "Field Nurse", "soviet", "inf", 2, "common", "inf_medic",
      "Drags men twice her weight out of the fire, singing.", [A("medic")]),
    U("razvedchiki", "Razvedchiki Scouts", "soviet", "inf", 2, "common", "inf_scout",
      "White smocks in white snow. You will not see them.", [A("spotter")]),
    U("t34", "T-34/85", "soviet", "arm", 6, "common", "tank_t34",
      "Wide tracks for the mud, sloped plate for the shells. The tractor-works make one an hour.",
      [A("combined", 2)]),
    U("kv1", "KV-1", "soviet", "arm", 8, "uncommon", "tank_kv1",
      "A moving keep. Shot glances off it like hail off a church bell.", [A("entrench")]),
    U("katyusha", "Katyusha", "soviet", "arm", 4, "uncommon", "gun_katyusha",
      "A wagon of organ pipes that sings fire. The other side calls it Stalin's organ.",
      [A("barrage", 2, row="inf")]),
    U("studebaker", "Studebaker Truck", "soviet", "arm", 2, "common", "car_truck",
      "Came across the sea with flour, boots and a thousand cans of meat.", [A("supply")]),
    U("il2", "Il-2 Sturmovik", "soviet", "air", 6, "uncommon", "air_il2",
      "A flying tank. Its bathtub of armour shrugs off arrows and worse.",
      [A("artillery", 3, row="arm")]),
    U("yak3", "Yak-3", "soviet", "air", 5, "common", "air_yak",
      "Light as a swift and as quick to turn.", [A("combined", 2)]),
    # ------------------------------------------------------------------ specials (merchants & exploration only)
    U("tiger2", "Tiger II", "axis", "arm", 12, "special", "tank_tiger2",
      "Found crated in a barrow-mound: a beetle the size of a chapel.", [A("elite")], special=True),
    U("me262", "Me 262", "axis", "air", 9, "special", "air_me262",
      "A falcon with no propeller at all. It screams past before the thunder arrives.",
      [A("combined", 2)], special=True),
    U("mosquito", "de Havilland Mosquito", "allies", "air", 7, "special", "air_mosquito",
      "Made of wood, like a good cart, and faster than anything with feathers.",
      [A("spotter"), A("artillery", 3, row="arm")], special=True),
    U("is2", "IS-2", "soviet", "arm", 11, "special", "tank_is2",
      "Its gun fires a shell the weight of a ten-year-old child.", [A("elite")], special=True),
    # ------------------------------------------------------------------ tactics (any deck)
    T("mud", "Mud Season", "weather", "common", "tac_mud",
      "Spring thaw turns every road into porridge. Iron wagons sink to the axles.", row_target="arm"),
    T("fog", "Channel Fog", "weather", "common", "tac_fog",
      "Grey wool over the sea. No bird of iron flies today.", row_target="air"),
    T("frost", "Hard Frost", "weather", "common", "tac_frost",
      "So cold the grease freezes in the rifles and the men freeze to the grease.", row_target="inf"),
    T("smoke", "Smoke Screen", "clear", "common", "tac_smoke",
      "Canisters that hiss white clouds: whatever blinded the field is gone."),
    T("air_superiority", "Air Superiority", "air_superiority", "uncommon", "tac_air",
      "Own the sky and the rest follows. Clears fog; your Air units gain +2 this round."),
    T("pincer", "Pincer Movement", "pincer", "rare", "tac_pincer",
      "Two arrows on the map close like a smith's tongs."),
    T("codebreakers", "Bletchley Park Codebreakers", "codebreakers", "rare", "tac_codebreakers",
      "Clever folk in a country house, reading the enemy's letters before he does."),
    T("fortitude", "Operation Fortitude", "decoy", "uncommon", "tac_fortitude",
      "An army of painted canvas and rubber tanks, inflated by four men and a bicycle pump."),
    T("doctrine", "Blitzkrieg Doctrine", "doctrine", "uncommon", "tac_doctrine",
      "Speed, surprise, iron. Your Armour gains +2 this round (+3 in Blitzkrieg)."),
    T("barrage", "Rolling Barrage", "barrage", "uncommon", "tac_barrage",
      "A wall of shells that walks across the field a few yards ahead of the infantry."),
    T("enigma", "Enigma Machine", "codebreakers", "special", "tac_enigma",
      "A typewriter with brass wheels that scrambles every letter. This one was dug out of a ruin.",
      special=True, draw=1),
]

RULES_TEXT = {
    "abilities": {
        "spotter": "Spotter — reveals two cards in the opponent's hand.",
        "artillery": "Artillery N — hits the strongest enemy unit in the named row for N.",
        "barrage": "Barrage N — hits every enemy unit in the named row for N.",
        "entrench": "Entrench — ignores weather and the next hit from artillery, assault or a pincer.",
        "combined": "Combined Arms N — +N while you hold a unit in another row.",
        "supply": "Supply Line — draw a card.",
        "reinforce": "Reinforce — calls the rest of its company (or its passengers) out of your deck.",
        "medic": "Medic — returns your strongest fallen unit to your hand.",
        "assault": "Assault N — strikes the weakest enemy unit in the same row for N.",
        "rally": "Rally N — every other unit in its row gains +N.",
        "elite": "Elite — immune to weather, tactics and damage; never boosted.",
    },
    "tactics": {
        "weather": "Weather — every non-elite unit in that row, on both sides, counts as 1.",
        "clear": "Clears all weather.",
        "air_superiority": "Clears fog; your Air units gain +2 this round.",
        "pincer": "Destroys the strongest enemy unit (all ties) if it has 8 or more strength.",
        "codebreakers": "Reveals the opponent's whole hand for the round and steals one random card from it.",
        "decoy": "Play onto one of your units: it returns to your hand and the decoy takes its place at 0.",
        "doctrine": "Your Armour gains +2 this round (+3 in Blitzkrieg).",
        "barrage": "Hits every enemy unit in their most crowded row for 2.",
        "draw": "Draw two cards.",
    },
}

COMMANDERS = [
    dict(id="supreme_commander", name="The Supreme Commander", faction="allies", effect="clear_draw",
         text="Clear all weather and draw a card."),
    dict(id="air_marshal", name="The Air Marshal", faction="allies", effect="boost_air",
         text="Your Air units gain +2 this round."),
    dict(id="field_marshal", name="The Field Marshal", faction="axis", effect="boost_arm",
         text="Your Armour units gain +2 this round."),
    dict(id="chief_of_intelligence", name="The Chief of Intelligence", faction="axis", effect="reveal_draw",
         text="Reveal the opponent's hand for the round and draw a card."),
    dict(id="front_commander", name="The Front Commander", faction="soviet", effect="summon_inf",
         text="Call up to two Infantry units from your deck onto the field."),
    dict(id="general_winter", name="General Winter", faction="soviet", effect="frost_enemy",
         text="Hard Frost on the Infantry row; your own Infantry is entrenched against it."),
]

FACTIONS = {
    "allies": dict(name="Western Allies", color="#5e6a3e", text="Many tanks, many planes, much tea."),
    "axis": dict(name="Axis", color="#5a5e62", text="Few, heavy and terrible machines."),
    "soviet": dict(name="Soviets", color="#7a3a2c", text="Endless companies and very hard frost."),
    "neutral": dict(name="Tactics", color="#7a6440", text="Any deck may use them."),
}

DECK_RULES = dict(min=22, max=30, min_units=14, copies=dict(common=3, uncommon=2, rare=1, special=1))


def deck(name, faction, commander, cards):
    return dict(name=name, faction=faction, commander=commander, cards=cards)


STARTER_DECK = deck("Barnaby's Loaner (Allies)", "allies", "supreme_commander", {
    "rifle_squad": 3, "tommies": 3, "airborne": 2, "combat_medic": 1, "forward_observer": 1, "commandos": 1,
    "sherman": 3, "jeep": 2, "churchill": 1, "m7_priest": 1,
    "dakota": 2, "spitfire": 2,
    "mud": 1, "fog": 1, "smoke": 1})
# v1.7 (#70): Barnaby's teaching box — the modest Axis deck he plays in the teaching match (a fixed deal,
# Ironfront.TEACHING_SEED), so a newcomer following his suggestions wins a real game. Never in anyone's collection.
TEACHING_DECK = {"name": "Barnaby's teaching box", "faction": "axis", "commander": "field_marshal",
                 "cards": {"grenadiers": 4, "mg42": 2, "field_surgeon": 1, "panzer_iv": 3, "stug": 2, "halftrack": 2,
                           "bf109": 3, "ju52": 2, "mud": 1, "fog": 1, "frost": 1}}

STARTER_EXTRA = {"rifle_company": 3, "t34": 2, "yak3": 2, "razvedchiki": 1, "studebaker": 1, "field_nurse": 1,
                 "grenadiers": 2, "panzer_iv": 2, "bf109": 1, "frost": 1}

OPPONENTS = [
    dict(id="jory", name="Jory Thatch", tier=1, unlock="", portrait="portraits/jory",
         title="Farmer, plays on market days",
         style="Cautious. Plays his strongest cards early and rarely bluffs.",
         greet="\"I don't hold with iron wagons, mind. But the frost card, now — that's honest weather.\"",
         ai=dict(skill=0.35, bluff=0.05, greed=0.7),
         deck=deck("Jory's Snow Company", "soviet", "general_winter", {
             "rifle_company": 3, "guards": 1, "field_nurse": 3, "razvedchiki": 2, "katyusha": 1,
             "t34": 3, "studebaker": 3, "yak3": 3, "frost": 2, "smoke": 1})),
    dict(id="barnaby", name="Barnaby Quill", tier=2, unlock="", portrait="portraits/barnaby",
         title="Host of the basement war-room",
         style="Knows every card. Holds tactics back for the right moment and enjoys a bluff.",
         greet="\"Ah! A challenger! Mind the Tiger, she's freshly painted. Helmet on — regulations.\"",
         ai=dict(skill=0.85, bluff=0.2, greed=0.45),
         deck=deck("Barnaby's Panzer Lehr", "axis", "field_marshal", {
             "grenadiers": 3, "mg42": 2, "panzerfaust": 2, "field_surgeon": 1,
             "panzer_iv": 3, "stug": 2, "panther": 2, "tiger": 1, "halftrack": 2, "flak88": 1,
             "bf109": 2, "stuka": 1, "ju52": 1, "mud": 1, "fog": 1, "doctrine": 1, "fortitude": 1})),
    dict(id="pip", name="Pip Underbough", tier=2, unlock="wins:1", portrait="portraits/pip",
         title="Bard, card-sharp, liar",
         style="Bluffs constantly, passes early, loves tricks and codebreakers.",
         greet="\"Shall we make it interesting? No? Pity. I'll be Montgomery, you be confused.\"",
         ai=dict(skill=0.8, bluff=0.25, greed=0.5),
         deck=deck("Pip's Airborne Caper", "allies", "air_marshal", {
             "m7_priest": 2, "airborne": 3, "commandos": 2, "rangers": 2, "forward_observer": 2, "combat_medic": 1,
             "sherman": 3, "churchill": 2, "dakota": 2, "spitfire": 2, "mustang": 1,
             "codebreakers": 1, "fortitude": 1, "fog": 1, "smoke": 1, "air_superiority": 1})),
    dict(id="sigrun", name="Sigrun Halvard", tier=3, unlock="beat:barnaby", portrait="portraits/sigrun",
         title="Shield-maiden who plays for keeps",
         style="Aggressive and exact. Counts every point and never wastes a card.",
         greet="\"Barnaby says you beat him. Show me.\"",
         ai=dict(skill=1.0, bluff=0.15, greed=0.35),
         deck=deck("Sigrun's Iron Wall", "soviet", "front_commander", {
             "rifle_company": 3, "guards": 2, "snipers": 2, "field_nurse": 1, "razvedchiki": 2,
             "t34": 3, "kv1": 2, "katyusha": 2, "studebaker": 1,
             "il2": 2, "yak3": 2, "pincer": 1, "barrage": 1, "frost": 1, "smoke": 1})),
]

SHOP = dict(pack_price=60, pack_size=5, pack_odds=dict(common=0.68, uncommon=0.25, rare=0.07),
            single_price=dict(common=15, uncommon=35, rare=90), sell_singles=6)
REWARDS = dict(gold_win=[0, 20, 35, 55], gold_loss=8, cards_win=[0, 1, 1, 2],
               tier_odds={"1": dict(common=0.8, uncommon=0.18, rare=0.02),
                          "2": dict(common=0.6, uncommon=0.32, rare=0.08),
                          "3": dict(common=0.4, uncommon=0.42, rare=0.18)})

BLITZ = dict(hand=8, plays=7, momentum_plays=2, momentum=2, assault_bonus=1)

data = dict(cards=CARDS, commanders=COMMANDERS, factions=FACTIONS, deck_rules=DECK_RULES, starter_deck=STARTER_DECK,
            starter_extra=STARTER_EXTRA, teaching_deck=TEACHING_DECK, opponents=OPPONENTS, shop=SHOP, rewards=REWARDS, blitz=BLITZ, rules=RULES_TEXT)

if __name__ == "__main__":
    ids = [c["id"] for c in CARDS]
    assert len(ids) == len(set(ids)), "duplicate card id"
    groups = {}
    for c in CARDS:
        groups.setdefault(c.get("group", ""), []).append(c["id"])
    for o in OPPONENTS + [dict(id="starter", deck=STARTER_DECK)]:
        d = o["deck"]
        n = sum(d["cards"].values())
        assert DECK_RULES["min"] <= n <= DECK_RULES["max"], (o["id"], n)
        for cid, k in d["cards"].items():
            c = next(x for x in CARDS if x["id"] == cid)
            assert c["faction"] in (d["faction"], "neutral"), (o["id"], cid)
            assert k <= DECK_RULES["copies"][c["rarity"]], (o["id"], cid, k)
        units = sum(k for cid, k in d["cards"].items() if next(x for x in CARDS if x["id"] == cid)["type"] == "unit")
        assert units >= DECK_RULES["min_units"], (o["id"], units)
    with open(OUT, "w") as f:
        json.dump(data, f, indent=1, ensure_ascii=False)
    print("ironfront cards:", len(CARDS), "->", os.path.abspath(OUT))
