"""The Living Realm (milestone 2a) — the evolving smithy: discipline areas and the Loft.

Applied by make_layout.py right after the smithy's base data. Adds to building "smithy":

  room_disciplines  {room_id: discipline}   what each workshop room is meant for (signs, auto-placement, the layout
                                            editor); a room's stations still decide what it shows once it has them
  floors            [{id, name, area, rect, entrance, stairs, arrive_down, lift, lift_arrive}]   in PLAN coordinates
  rooms/room_doors/units/room_kinds         the Loft's rooms, doorways and the two purchasable sections
  reserved          [[x, y, w, h]]           floor kept clear of stations (stairwell, hoist shaft) — plan coordinates

and the off-map area "smithy_loft" (the Loft as the world renders it: floor, dressing, spots).

PLAN coordinates: the smith's property plan (Property) keeps every floor in the smithy's own tile coordinates. The
ground floor is the building rect [0, 0, 30, 23]; the Loft sits at LOFT_OFF = (100, 18), i.e. its world area is the
smithy's world position + (100, 18) — east of the map below the inn's upper floor. So a station standing at plan
(110.0, 27.0) is drawn at smithy origin + (110, 27) tiles, which is inside the Loft area, and every existing helper
(Property.pos_of, world.station_pos, footprints, room lookups) keeps working unchanged across floors.

Why a loft (design): the weaving & tailoring trade outgrew Ilse's room (eight stations, six places) and textiles
want what a loft gives — dry air and light from the dormers; the forge's rising heat makes the space over the
smithing hall the village's best drying loft for herbs, and the quiet garret over the rune room suits a rune
scriptorium. The outside footprint stays the same: the Loft lies under the existing roof over the west and central
wings (the east wing keeps the apartment's own roof). It is reached by a stair from the stock hall, and later by
Ilse's old goods hoist in the leather room, re-rigged with a ley-stone from the Arcane Foundry as an aetheric lift.
"""

LOFT_OFF = (100, 18)
LOFT_SIZE = (30, 16)        # v1.7: the household's wing (x 19–30) beside Ilse's loft and the garret
BASE_OFF = (100, 40)        # v1.7 (#66): the basement, dug out under the smithy (plan coordinates, like the Loft)
BASE_SIZE = (24, 8)
SMITHY_WORLD = (18, 34)
GROUND = (19, 18)           # v1.7 (#64): the compact ground floor

# v1.7 (#64–66), "The Living Village & Workshop" (canonical v1.7 §4.1): the ground floor keeps the smithing hall, the
# shopfront, the stock hall and the three neighbours' workshop rooms (19 × 18, about half the old 30 × 23). The
# household lives in the Loft: a small room with a cot, the ledger desk and the deeds from the start (with the stair
# landing), the Ashbys' old rooms — living room, bedroom, storage, pantry — as the "apartment" upgrade under the same
# roof. The material store and the arcane foundry are dug out of the basement, absent at the start: a first dig (a
# stair down from the stock hall and a cellar store) and a deeper one (the vault for the foundry). Room ids are kept,
# so saves, stations and upgrades carry over (SaveMigrations moves what an older plan held).


def apply(layout, s, room, door, FT, F):
    ox, oy = LOFT_OFF

    def P(x, y):
        return [round(x + ox, 3), round(y + oy, 3)]

    # ---------------------------------------------------------------- discipline areas (ground floor)
    disc = {"forge_room": "classic", "rune_room": "runecraft", "alchemy_room": "alchemy", "leather_room": "stitching",
            "arcane_room": "arcane", "material_store": "",
            "loft_weaving": "stitching", "loft_drying": "alchemy", "loft_scriptorium": "runecraft"}

    # ---------------------------------------------------------------- the Loft (local coordinates → plan)
    loft_rooms_local = [
        # v1.7: the household's rooms under the roof (ids kept from the old ground-floor east wing)
        room("study", "Your quarters — under the roof", [19, 0, 5, 6], "floor_wood", None, "wall_plaster"),
        room("living", "Living & Dining Room", [24, 0, 6, 7], "floor_wood", None, "wall_plaster"),
        room("bedroom", "Bedroom", [24, 7, 6, 9], "floor_wood", None, "wall_plaster"),
        room("storage", "Personal Storage", [19, 6, 5, 5], "floor_wood", None, "wall_plaster"),
        room("pantry", "Pantry & Washroom", [19, 11, 5, 5], "floor_stone", None, "wall_plaster"),
        room("loft_landing", "Loft Landing", [10, 0, 9, 5], "floor_wood"),
        room("loft_weaving", "Weaving & Tailoring Loft", [10, 5, 9, 11], "floor_wood", [1.0, 0.97, 0.9]),
        room("loft_drying", "Drying Loft", [0, 0, 10, 9], "floor_herb", [0.97, 1.0, 0.92]),
        room("loft_scriptorium", "Rune Scriptorium", [0, 9, 10, 7], "floor_slate", [0.93, 0.95, 1.0], "wall_stone"),
    ]
    loft_rooms = []
    for r in loft_rooms_local:
        rr = dict(r)
        x, y, w, h = r["rect"]
        rr["rect"] = [x + ox, y + oy, w, h]
        loft_rooms.append(rr)
    # door "at" is the coordinate along the shared edge (x for a horizontal wall, y for a vertical one)
    loft_doors = [
        door("loft_landing", "loft_weaving", 15 + ox),        # horizontal wall y = 5
        door("loft_landing", "loft_drying", 1 + oy),          # vertical wall x = 10
        door("loft_drying", "loft_scriptorium", 4 + ox),      # horizontal wall y = 9
        door("loft_weaving", "loft_scriptorium", 12 + oy),    # vertical wall x = 10
        door("loft_landing", "study", 2 + oy),                # vertical wall x = 19 (the household's own door)
        door("study", "living", 2 + oy),                      # vertical wall x = 24
        door("living", "bedroom", 27 + ox),                   # horizontal wall y = 7
        door("study", "storage", 21 + ox),                    # horizontal wall y = 6
        door("storage", "pantry", 21 + ox),                   # horizontal wall y = 11
    ]
    moved = {"study", "living", "bedroom", "storage", "pantry"}
    # never add twice when make_layout runs again on its own output
    s["rooms"] = [r for r in s["rooms"] if not r["id"].startswith("loft_") and r["id"] not in moved] + loft_rooms
    s["room_doors"] = [d for d in s["room_doors"] if not d["between"][0].startswith("loft_") and d["between"][0] not in moved] + loft_doors
    s["room_kinds"].update({"loft_landing": "store", "loft_weaving": "workshop", "loft_drying": "workshop", "loft_scriptorium": "workshop"})
    s["room_disciplines"] = disc
    # v1.7: the stair landing and the quarters are the smith's from the start; the Ashby rooms are the Loft's household
    # wing; the cellar store and the vault are dug, not bought from a neighbour
    keep = [u for u in s["units"] if u["id"] not in ("loft", "garret", "start", "chandler", "cellar", "apartment")]
    s["units"] = [
        dict(id="start", name="Ironhand Smithy", rooms=["shop", "forge_room", "stock_hall", "loft_landing", "study"], price=0,
             occupant="Brannoc Ironhand",
             desc="A modest shopfront, a smoky smithing hall and a narrow stock hall — and up the stair, a small room under the roof with a cot."),
    ] + keep + [
        dict(id="chandler", name="The Cellar Dig", rooms=["cellar_stair", "material_store"], price=300, floor="basement", requires="start",
             occupant="solid earth under the stock hall",
             desc="Dig out a dry cellar under the smithy: a stair down from the stock hall and a store-room for ore, coal and hides.",
             becomes="a cellar store, reached by a stair from the stock hall"),
        dict(id="cellar", name="The Deep Vault", rooms=["arcane_room"], price=950, floor="basement", requires="chandler",
             occupant="the old dye-works' foundations",
             desc="Dig on under the cellar into the old dye-works' foundations: a long vault with thick stone walls, fit to hold arcane energies.",
             becomes="an arcane foundry"),
        dict(id="apartment", name="The Household Wing", rooms=["living", "bedroom", "storage", "pantry"], price=700, floor="loft",
             occupant="the Ashby family's old rooms under the roof",
             desc="The rest of the roof space beside your quarters: a living room with a hearth, a bedroom, storage and a pantry with a bath.",
             becomes="your home"),
        dict(id="loft", name="Ilse's Loft", rooms=["loft_weaving"], price=650, floor="loft", requires="weaver",
             occupant="Ilse the weaver (her looms and bolts under the roof)",
             desc="The long loft under the roof above her room: dormer light, dry air and Ilse's old goods hoist. She lets it go with her room.",
             becomes="a weaving & tailoring loft, reached by a stair from the stock hall"),
        dict(id="garret", name="The West Garret", rooms=["loft_drying", "loft_scriptorium"], price=480, floor="loft", requires="loft",
             occupant="the reeve's archive (old tithe rolls nobody reads)",
             desc="Two quiet rooms under the west roof: one warm over the forge, one cool over the stone rune room.",
             becomes="a drying loft for herbs and a rune scriptorium"),
    ]

    # stairwell in the stock hall ↔ the Loft landing; the hoist shaft in the leather room ↔ the weaving loft
    ground_stairs = [12.4, 7.4]
    loft_stairs_local = [12.0, 2.3]
    ground_lift = [16.0, 13.6]
    loft_lift_local = [16.0, 13.6]
    bx, by = BASE_OFF

    def B(x, y):
        return [round(x + bx, 3), round(y + by, 3)]

    base_stairs_ground = [17.7, 8.1]      # the stair down, by the stock hall's east wall
    base_stairs_local = [2.5, 1.4]
    s["floors"] = [
        dict(id="ground", name="Ground floor", rect=[0, 0, GROUND[0], GROUND[1]], entrance=[14.0, 0.6]),
        dict(id="loft", name="The Loft", area="smithy_loft", rect=[ox, oy, LOFT_SIZE[0], LOFT_SIZE[1]],
             entrance=P(12.0, 3.9),                 # where the stair brings you up
             stairs=P(*loft_stairs_local), down_stairs=ground_stairs, arrive_down=[12.4, 9.1],
             lift=P(*loft_lift_local), lift_arrive=P(16.0, 15.0), down_lift=ground_lift, lift_arrive_down=[16.0, 15.0],
             units=["loft", "garret", "apartment"]),
        dict(id="basement", name="The Cellar", area="smithy_basement", rect=[bx, by, BASE_SIZE[0], BASE_SIZE[1]], below=True,
             entrance=B(2.5, 3.2), stairs=B(*base_stairs_local), down_stairs=base_stairs_ground, arrive_down=[16.2, 8.4],
             units=["chandler", "cellar"]),
    ]
    s["reserved"] = [
        [ground_stairs[0] - 0.85, ground_stairs[1] - 1.1, 1.7, 2.2],
        [ground_lift[0] - 0.75, ground_lift[1] - 0.75, 1.5, 1.5],
        [loft_stairs_local[0] + ox - 0.85, loft_stairs_local[1] + oy - 1.1, 1.7, 2.2],
        [loft_lift_local[0] + ox - 0.75, loft_lift_local[1] + oy - 0.75, 1.5, 1.5],
        [base_stairs_ground[0] - 0.85, base_stairs_ground[1] - 1.1, 1.7, 2.2],
        [base_stairs_local[0] + bx - 0.85, base_stairs_local[1] + by - 1.1, 1.7, 2.2],
    ]
    s["lift"] = dict(price=300, requires_unit="loft", requires_upgrade="arcane_foundry")
    # the sack in the stock hall stood where the stair now rises
    s["furniture"] = [f for f in s["furniture"] if not (f[0] == "sack" and abs(f[1] - 12.0) < 0.01 and abs(f[2] - 6.7) < 0.01)]
    # v1.7: the barrel by the stock hall's east wall gave way to the cellar stair
    s["furniture"] = [f for f in s["furniture"] if not (f[0] in ("barrel", "sack") and f[1] > 17.0 and 6.0 < f[2] < 7.5)]

    # ---------------------------------------------------------------- the Loft as a world area
    furn = [
        # landing: a rope-railed stair head, a bench for bolts of cloth
        FT("crate", 18.3, 0.6, 0, "own"), FT("sack", 17.4, 0.6, 0, "own"), FT("candle", 14.6, 0.5, 0, "own"),
        # weaving loft: dormer-lit, bolts and baskets along the walls
        FT("leather_bundle", 18.3, 6.0, 0, "bare"), FT("crate", 11.0, 15.3, 0, "bare"),
        # drying loft: herb garlands hang from the rafters (flat)
        FT("herb_garlands", 3.0, 0.5, 0, "own"), FT("herb_garlands", 7.0, 0.5, 0, "own"), FT("sack", 0.7, 8.2, 0, "bare"),
        # scriptorium
        FT("candle", 0.7, 9.7, 0, "own"), FT("bookshelf", 3.0, 15.5, 0, "own"),
        # v1.7: your quarters under the roof — a cot, the ledger desk, a shelf of deeds, a dresser and the vase
        F("bed", 20.2, 3.6), F("desk_ledger", 23.3, 2.6, 90), F("bookshelf", 21.8, 0.55), F("dresser", 22.6, 5.3),
        F("candle", 23.3, 2.4), F("vase", 19.6, 0.7),
        # the household wing: hearth and table, the bedroom, storage, pantry with a bath
        F("dining_table", 27.0, 3.6), F("chair", 25.4, 3.6), F("chair", 28.6, 3.6), F("fireplace", 28.0, 0.7),
        F("cupboard", 29.4, 5.4, 90), F("trophy_wall", 25.6, 0.55), F("chair", 25.2, 1.6), F("candle", 27.0, 3.4),
        F("bed_double", 28.6, 9.6), F("nightstand", 26.9, 9.6), F("dresser", 25.0, 14.8), F("wardrobe", 29.3, 13.6, 90),
        F("rug_brown", 27.2, 12.6), F("candle", 26.9, 9.5),
        F("chest", 23.2, 7.4), F("chest", 20.0, 9.9), F("wardrobe", 19.6, 7.6, 90),
        F("bath_tub", 22.6, 14.6), F("kitchen_stove", 20.2, 11.9), F("shelf", 23.4, 12.6, 90), F("produce_crate", 20.2, 14.8),
    ]
    loft_interact = [
        dict(kind="bed", id="cot", pos=[20.2, 3.6], r=100, label="Your cot — sleep until morning (autosave)"),
        dict(kind="ledger", id="study_desk", pos=[23.3, 2.6], r=110, label="Your ledger — accounts, journal & upgrades"),
        dict(kind="property", id="deeds", pos=[21.8, 0.9], r=100, label="Deeds, plans & workshop equipment"),
        dict(kind="customize", id="mirror", pos=[22.6, 5.0], r=90, label="Mirror — change your appearance"),
        dict(kind="vase", id="quarters", pos=[19.6, 1.0], r=80, label="The vase"),
        dict(kind="bed", id="player_bed", pos=[28.6, 9.6], r=120, label="Your bed — sleep until morning (autosave)"),
        dict(kind="customize", id="bedroom_mirror", pos=[25.0, 14.8], r=90, label="Mirror — change your appearance"),
        dict(kind="bed", id="armchair", pos=[25.2, 1.6], r=90, label="Sit by the hearth — rest"),
    ]
    area = dict(id="smithy_loft", name="The Loft — Ironhand Forge",
                rect=[SMITHY_WORLD[0] + ox, SMITHY_WORLD[1] + oy, LOFT_SIZE[0], LOFT_SIZE[1]], floor="floor_wood",
                furniture=furn, spots={"smithy_loft_inside": [14.5, 3.6], "quarters_table": [27.0, 2.4], "quarters_bed": [27.0, 11.4]},
                interact=loft_interact, plan_offset=[ox, oy], floor_of="smithy")
    layout["areas"] = [a for a in layout["areas"] if a["id"] != "smithy_loft"] + [area]

    # ---------------------------------------------------------------- v1.7 (#66): the basement (dug, not bought)
    base_rooms_local = [
        room("cellar_stair", "Cellar Stair", [0, 0, 5, 8], "floor_stone", [0.9, 0.88, 0.86], "wall_stone"),
        room("material_store", "Material Store", [5, 0, 7, 8], "floor_stone", [0.94, 0.92, 0.88], "wall_stone"),
        room("arcane_room", "Arcane Foundry", [12, 0, 12, 8], "floor_arcane", [0.92, 0.88, 1.0], "wall_stone"),
    ]
    base_rooms = []
    for r in base_rooms_local:
        rr = dict(r)
        x, y, w, h = r["rect"]
        rr["rect"] = [x + bx, y + by, w, h]
        base_rooms.append(rr)
    base_doors = [door("cellar_stair", "material_store", 3 + by), door("material_store", "arcane_room", 3 + by)]
    bmoved = {"cellar_stair", "material_store", "arcane_room"}
    s["rooms"] = [r for r in s["rooms"] if r["id"] not in bmoved] + base_rooms
    s["room_doors"] = [d for d in s["room_doors"] if not (set(d["between"]) & bmoved)] + base_doors
    s["room_kinds"].update({"cellar_stair": "store", "material_store": "workshop", "arcane_room": "workshop"})
    # stations keep their places within their rooms (the store's loom and cutting table, the foundry's five)
    s["station_pos"].update({
        "loom": B(7.0, 2.6), "cutting_table": B(10.4, 2.6),
        "arcane_crucible": B(13.6, 2.6), "spellbinding_array": B(17.4, 2.6), "leyline_conductor": B(20.0, 1.7),
        "arcane_anvil": B(22.3, 3.6), "aetheric_stabilizer": B(22.6, 1.4),
    })
    bfurn = [
        # undug: packed earth and rubble where the rooms will be
        FT("stone_blocks", 3.0, 5.5, 0, "occ"), FT("stone_blocks", 8.5, 4.0, 0, "occ"), FT("sack", 6.0, 6.8, 0, "occ"),
        FT("stone_blocks", 15.0, 4.0, 0, "occ"), FT("stone_blocks", 20.0, 5.0, 0, "occ"), FT("crate", 18.0, 6.8, 0, "occ"),
        # the cellar store
        FT("coal_pile", 6.0, 6.8, 0, "own"), FT("ore_pile", 8.0, 7.2, 0, "own"), FT("barrel", 11.3, 0.8, 0, "own"),
        FT("crate", 9.6, 7.2, 0, "own"), FT("grain_sacks", 11.2, 6.9, 0, "own"), FT("ingredient_crates", 6.0, 5.4, 0, "own"),
        FT("leather_bundle", 11.2, 5.4, 0, "own"), FT("candle", 1.0, 0.6, 0, "own"),
        # the vault
        FT("arcane_glyph_decal", 17.4, 2.6, 0, "ws:arcane"), FT("arcane_rack", 15.4, 7.3, 0, "ws:arcane"),
    ]
    barea = dict(id="smithy_basement", name="The Cellar — Ironhand Forge",
                 rect=[SMITHY_WORLD[0] + bx, SMITHY_WORLD[1] + by, BASE_SIZE[0], BASE_SIZE[1]], floor="floor_stone",
                 furniture=bfurn, spots={"smithy_basement_inside": [2.5, 4.5]}, interact=[], plan_offset=[bx, by], floor_of="smithy")
    layout["areas"] = [a for a in layout["areas"] if a["id"] != "smithy_basement"] + [barea]
