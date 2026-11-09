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
LOFT_SIZE = (19, 16)
SMITHY_WORLD = (18, 34)


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
    ]
    # never add twice when make_layout runs again on its own output
    s["rooms"] = [r for r in s["rooms"] if not r["id"].startswith("loft_")] + loft_rooms
    s["room_doors"] = [d for d in s["room_doors"] if not d["between"][0].startswith("loft_")] + loft_doors
    s["room_kinds"].update({"loft_landing": "store", "loft_weaving": "workshop", "loft_drying": "workshop", "loft_scriptorium": "workshop"})
    s["room_disciplines"] = disc
    s["units"] = [u for u in s["units"] if u["id"] not in ("loft", "garret")] + [
        dict(id="loft", name="Ilse's Loft", rooms=["loft_landing", "loft_weaving"], price=650, floor="loft", requires="weaver",
             occupant="Ilse the weaver (her looms and bolts under the roof)",
             desc="The long loft under the roof above her room: dormer light, dry air and Ilse's old goods hoist. She lets it go with her room.",
             becomes="a weaving & tailoring loft, reached by a stair from the stock hall"),
        dict(id="garret", name="The West Garret", rooms=["loft_drying", "loft_scriptorium"], price=480, floor="loft",
             occupant="the reeve's archive (old tithe rolls nobody reads)",
             desc="Two quiet rooms under the west roof: one warm over the forge, one cool over the stone rune room.",
             becomes="a drying loft for herbs and a rune scriptorium"),
    ]

    # stairwell in the stock hall ↔ the Loft landing; the hoist shaft in the leather room ↔ the weaving loft
    ground_stairs = [12.4, 7.4]
    loft_stairs_local = [12.0, 2.3]
    ground_lift = [16.0, 13.6]
    loft_lift_local = [16.0, 13.6]
    s["floors"] = [
        dict(id="ground", name="Ground floor", rect=[0, 0, 30, 23], entrance=[14.0, 0.6]),
        dict(id="loft", name="The Loft", area="smithy_loft", rect=[ox, oy, LOFT_SIZE[0], LOFT_SIZE[1]],
             entrance=P(12.0, 3.9),                 # where the stair brings you up
             stairs=P(*loft_stairs_local), down_stairs=ground_stairs, arrive_down=[12.4, 9.1],
             lift=P(*loft_lift_local), lift_arrive=P(16.0, 15.0), down_lift=ground_lift, lift_arrive_down=[16.0, 15.0],
             units=["loft", "garret"]),
    ]
    s["reserved"] = [
        [ground_stairs[0] - 0.85, ground_stairs[1] - 1.1, 1.7, 2.2],
        [ground_lift[0] - 0.75, ground_lift[1] - 0.75, 1.5, 1.5],
        [loft_stairs_local[0] + ox - 0.85, loft_stairs_local[1] + oy - 1.1, 1.7, 2.2],
        [loft_lift_local[0] + ox - 0.75, loft_lift_local[1] + oy - 0.75, 1.5, 1.5],
    ]
    s["lift"] = dict(price=300, requires_unit="loft", requires_upgrade="arcane_foundry")
    # the sack in the stock hall stood where the stair now rises
    s["furniture"] = [f for f in s["furniture"] if not (f[0] == "sack" and abs(f[1] - 12.0) < 0.01 and abs(f[2] - 6.7) < 0.01)]
    if not any(f[0] == "sack" and abs(f[1] - 17.7) < 0.01 for f in s["furniture"]):
        s["furniture"].append(F("sack", 17.7, 6.65))

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
    ]
    area = dict(id="smithy_loft", name="The Loft — Ironhand Forge",
                rect=[SMITHY_WORLD[0] + ox, SMITHY_WORLD[1] + oy, LOFT_SIZE[0], LOFT_SIZE[1]], floor="floor_wood",
                furniture=furn, spots={"smithy_loft_inside": [14.5, 3.6]}, interact=[], plan_offset=[ox, oy], floor_of="smithy")
    layout["areas"] = [a for a in layout["areas"] if a["id"] != "smithy_loft"] + [area]
