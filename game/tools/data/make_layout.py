"""Generates game/data/layout.json — the village and its multi-room interiors.

Buildings are rectangles (tiles, TILE = 64 px) subdivided into rooms. Interior walls are derived
automatically from the shared edges between rooms; `doors` cut gaps in them ("between" two rooms) or
in the outer wall ("side"). Furniture, NPC spots and interactables are placed in building-relative
tile coordinates. Station positions for the smithy are written here too (they override
stations.json "pos").  Run: python3 tools/data/make_layout.py
"""
import json, os

D = os.path.join(os.path.dirname(__file__), "..", "..", "data")


def room(id, name, rect, floor, tint=None, wall="wall_timber"):
    r = dict(id=id, name=name, rect=rect, floor=floor, wall=wall)
    if tint:
        r["tint"] = tint
    return r


def door(a, b, at, w=2):
    """Interior door between rooms a and b; `at` = start coordinate along the shared edge (tiles)."""
    return dict(between=[a, b], at=at, w=w)


def F(prop, x, y, rot=0):
    return [prop, x, y, rot]


def FT(prop, x, y, rot, tag):
    """Smithy furniture with a visibility tag: occ (neighbour's, while unowned), own (once owned),
    bare (owned, no station yet), ws:<discipline> (owned and that discipline's station in the room)."""
    return [prop, x, y, rot, tag]


# ======================================================================= the smithy
# 30 x 23 tiles. Industrial west wing, shopfront at the front door, private east wing.
SMITHY_ROOMS = [
    room("forge_room", "Smithing Hall", [0, 0, 10, 10], "floor_soot", [1.0, 0.92, 0.84], "wall_stone"),
    room("shop", "Shopfront", [10, 0, 9, 6], "floor_wood"),
    room("stock_hall", "Stock Hall", [10, 6, 9, 4], "floor_stone"),
    room("rune_room", "Runecrafting Room", [0, 10, 7, 8], "floor_slate", [0.92, 0.95, 1.0], "wall_stone"),
    room("alchemy_room", "Alchemy Room", [7, 10, 6, 8], "floor_herb", [0.95, 1.0, 0.92]),
    room("leather_room", "Leatherworking & Stitching", [13, 10, 6, 8], "floor_wood", [1.0, 0.96, 0.9]),
    room("arcane_room", "Arcane Foundry", [0, 18, 12, 5], "floor_arcane", [0.92, 0.88, 1.0], "wall_stone"),
    room("material_store", "Material Store", [12, 18, 7, 5], "floor_stone"),
    room("living", "Living & Dining Room", [19, 0, 11, 7], "floor_wood", None, "wall_plaster"),
    room("study", "Back Room — your quarters", [19, 7, 5, 6], "floor_wood", None, "wall_plaster"),
    room("bedroom", "Bedroom", [24, 7, 6, 9], "floor_wood", None, "wall_plaster"),
    room("storage", "Personal Storage", [19, 13, 5, 10], "floor_wood", None, "wall_plaster"),
    room("pantry", "Pantry & Washroom", [24, 16, 6, 7], "floor_stone", None, "wall_plaster"),
]
SMITHY_DOORS = [
    door("shop", "stock_hall", 15),              # staff door behind the counter
    door("forge_room", "stock_hall", 7),
    door("stock_hall", "alchemy_room", 11),
    door("stock_hall", "leather_room", 15),
    door("forge_room", "rune_room", 3),
    door("rune_room", "arcane_room", 3),
    door("leather_room", "material_store", 15),
    door("stock_hall", "study", 8),               # private wing entrance (through the study)
    door("living", "study", 20),
    door("living", "bedroom", 25),
    door("study", "storage", 20),
    door("bedroom", "pantry", 26),
]
SMITHY_STATIONS = {
    # A — traditional smithing (forge on the west wall under the chimney)
    "forge": [2.0, 2.2], "bellows": [4.5, 1.8], "anvil": [5.2, 5.4], "crucible": [1.7, 6.0],
    "quench_trough": [7.0, 8.8], "grinding_wheel": [8.4, 2.0],
    # B — runecrafting
    "rune_cutting_bench": [1.6, 12.0], "rune_engraving_stand": [5.7, 12.2], "rune_cleansing_basin": [1.5, 15.0],
    "resonance_pedestal": [5.5, 15.2], "rune_polishing_wheel": [1.5, 17.0],
    # C — alchemy
    "mortar_station": [8.2, 11.6], "infusion_rack": [11.7, 12.4], "alembic": [8.3, 14.2], "cauldron": [11.4, 15.3],
    "reagent_table": [8.7, 17.0],
    # E — leatherworking & enchanted stitching (the column x 15-17 stays clear between the doors)
    "stitching_table": [14.3, 11.8], "thread_spinner": [17.9, 12.2], "leather_vat": [14.2, 14.8],
    "embroidery_frame": [17.8, 15.0], "fitting_mannequin": [14.0, 17.2],
    # D — arcane metalworking (locked until the Arcane Foundry)
    "arcane_crucible": [1.6, 20.6], "spellbinding_array": [5.4, 20.6], "leyline_conductor": [8.0, 19.7],
    "arcane_anvil": [10.3, 21.6], "aetheric_stabilizer": [10.6, 19.4],
}
SMITHY_FURNITURE = [
    # forge room: soot, tools, metal stock (doors at x=10 y7-9 and y=10 x3-5 stay clear)
    F("soot_decal", 3.0, 3.4), F("tool_wall", 6.6, 0.55), F("iron_bars", 8.6, 4.6), F("coal_pile", 1.4, 4.2),
    F("ore_pile", 1.4, 8.6), F("woodpile", 8.8, 6.0),
    # shop: counter across the room, displays on the customer side
    F("shop_counter", 14.5, 3.6), F("weapon_rack", 17.3, 0.6), F("armor_stand", 11.0, 1.2), F("armor_stand", 12.3, 1.2),
    F("display_table", 17.4, 2.6), F("door_mat", 14.0, 0.5), F("candle", 16.2, 3.5),
    # stock hall (a short corridor: doors at x=10, y=6, y=10 and x=19 stay clear)
    F("crate", 13.9, 9.45), F("barrel", 18.4, 6.7), F("sack", 12.0, 6.7),
    # rune room
    FT("rune_shelf", 6.55, 13.7, 90, "ws:runecraft"), FT("rune_glyph_decal", 3.6, 14.0, 0, "ws:runecraft"),
    FT("stone_blocks", 6.2, 17.2, 0, "ws:runecraft"), FT("candle", 3.8, 16.8, 0, "own"),
    # alchemy
    FT("herb_rack", 9.0, 10.55, 0, "ws:alchemy"), FT("bottle_shelf", 11.0, 17.6, 0, "ws:alchemy"), FT("spill_decal", 10.0, 14.4, 0, "ws:alchemy"),
    # leather
    FT("pattern_board", 14.0, 10.55, 0, "ws:stitching"), FT("thread_spools", 18.3, 10.9, 0, "ws:stitching"), FT("hide_rack", 18.1, 17.3, 0, "ws:stitching"),
    # arcane foundry
    FT("arcane_glyph_decal", 5.4, 20.6, 0, "ws:arcane"), FT("arcane_rack", 3.4, 22.3, 0, "ws:arcane"),
    # material store
    FT("coal_pile", 13.4, 19.0, 0, "own"), FT("ore_pile", 15.0, 22.2, 0, "own"), F("barrel", 18.3, 18.8), F("barrel", 18.3, 19.8),
    FT("crate", 17.0, 22.2, 0, "own"), FT("woodpile", 17.4, 20.6, 0, "own"), FT("grain_sacks", 13.4, 22.0, 0, "own"),
    FT("ingredient_crates", 13.4, 20.6, 0, "own"), FT("leather_bundle", 18.2, 22.2, 0, "own"),
    # living & dining
    F("dining_table", 23.6, 3.8), F("chair", 21.6, 3.8), F("chair", 25.6, 3.8), F("chair", 23.0, 5.0), F("chair", 24.3, 5.0),
    F("fireplace", 27.8, 0.7), F("rug_red", 27.6, 3.4, 90), F("trophy_wall", 21.5, 0.55), F("cupboard", 29.2, 3.6, 90),
    F("candle", 23.6, 3.6),
    # study — the smith's cramped back room at first: a cot, the ledger desk and a shelf of deeds
    F("desk_ledger", 22.8, 9.8, 90), F("bookshelf", 23.0, 12.4), F("candle", 22.8, 9.6), F("bed", 20.4, 11.0),
    F("dresser", 20.4, 7.75), F("chair", 26.6, 1.9),
    # ---- what the neighbours keep in the rooms the smith does not own yet ("occ": shown only while unowned)
    FT("workbench", 3.0, 13.0, 0, "occ"), FT("leather_bundle", 1.4, 16.4, 0, "occ"), FT("shelf", 3.5, 10.55, 0, "occ"),
    FT("chair", 4.4, 14.2, 0, "occ"), FT("candle", 3.0, 12.8, 0, "occ"), FT("crate", 5.8, 16.8, 0, "occ"), FT("rug_brown", 3.4, 15.4, 0, "occ"),
    FT("washtub", 8.6, 12.0, 0, "occ"), FT("washtub", 11.2, 12.0, 0, "occ"), FT("barrel", 12.0, 16.8, 0, "occ"), FT("sack", 8.3, 16.8, 0, "occ"),
    FT("table_round", 10.0, 15.0, 0, "occ"), FT("chair", 9.0, 15.0, 0, "occ"), FT("shelf", 10.0, 10.55, 0, "occ"),
    FT("workbench", 15.6, 12.6, 0, "occ"), FT("chair", 16.4, 13.8, 0, "occ"), FT("chest", 14.2, 17.0, 0, "occ"), FT("rug_red", 16.0, 15.2, 0, "occ"),
    FT("crate", 13.5, 19.2, 0, "occ"), FT("crate", 14.7, 19.2, 0, "occ"), FT("sack", 13.5, 21.8, 0, "occ"), FT("shelf", 16.0, 18.55, 0, "occ"),
    FT("barrel", 2.0, 19.6, 0, "occ"), FT("barrel", 2.0, 20.8, 0, "occ"), FT("washtub", 5.0, 20.4, 0, "occ"), FT("washtub", 7.6, 20.4, 0, "occ"),
    FT("crate", 10.4, 21.8, 0, "occ"), FT("woodpile", 10.6, 19.4, 0, "occ"),
    # ---- a freshly bought room before the smith fills it ("bare": owned but no station in the room yet)
    FT("sack", 2.0, 11.4, 0, "bare"), FT("crate", 8.4, 16.8, 0, "bare"), FT("crate", 17.8, 16.8, 0, "bare"), FT("sack", 1.6, 21.8, 0, "bare"),
    # bedroom
    F("bed_double", 28.6, 9.6), F("nightstand", 26.9, 9.6), F("dresser", 25.0, 15.4), F("wardrobe", 29.3, 13.6, 90),
    F("rug_brown", 27.2, 12.6), F("candle", 26.9, 9.5),
    # personal storage
    F("chest", 23.2, 14.6), F("chest", 23.2, 16.0), F("wardrobe", 19.6, 18.0, 90), F("barrel", 23.2, 21.8), F("crate", 22.0, 21.8),
    F("sack", 20.2, 21.9),
    # pantry & washroom
    F("bath_tub", 28.6, 21.6), F("washtub", 25.2, 21.8), F("kitchen_stove", 25.0, 16.9), F("shelf", 29.4, 19.0, 90),
    F("produce_crate", 25.0, 19.2),
]
SMITHY_SPOTS = {
    "smithy_counter_front": [14.5, 2.0], "smithy_counter_back": [14.5, 4.9], "smithy_inside": [14.0, 1.4],
    "smithy_bag": [12.0, 7.6],
    "work_mining": [15.6, 20.4], "work_smithing": [6.8, 6.8], "work_alchemy": [10.0, 12.8], "work_runecraft": [3.6, 13.6],
    "work_travelling": [11.6, 4.8], "work_relic_hunting": [16.4, 8.0],
    "quarters_table": [23.6, 2.4], "quarters_bed": [27.0, 11.4],
}
# ---- the building is shared: the smith starts with the shopfront, the smithing hall, the stock hall and a back
# room; the neighbours' rooms can be bought as the business grows (only next to what he already owns).
SMITHY_UNITS = [
    dict(id="start", name="Ironhand Smithy", rooms=["shop", "forge_room", "stock_hall", "study"], price=0,
         occupant="Brannoc Ironhand", desc="A modest shopfront, a smoky smithing hall, a narrow stock hall and a back room with a cot."),
    dict(id="cobbler", name="Hesketh's Cobblery", rooms=["rune_room"], price=320, occupant="Old Hesketh, cobbler",
         desc="Stone-walled and cool, behind your forge. Hesketh wants to retire to his daughter's farm.", becomes="a runecrafting room"),
    dict(id="laundry", name="Widow Marla's Laundry", rooms=["alchemy_room"], price=360, occupant="Marla Wend, laundress",
         desc="Steam, tubs and lye. Good ventilation — an alchemist's dream.", becomes="an alchemy room"),
    dict(id="weaver", name="The Weaver's Room", rooms=["leather_room"], price=340, occupant="Ilse the weaver",
         desc="Bright, with long tables. Ilse is moving to the harbour lofts.", becomes="a leatherworking and stitching room"),
    dict(id="chandler", name="Chandler's Storeroom", rooms=["material_store"], price=240, occupant="Pell's chandlery (storage)",
         desc="Dry, with a loading door to the yard. Room for ore, coal and hides.", becomes="a material store"),
    dict(id="cellar", name="The Old Dye-Works", rooms=["arcane_room"], price=950, occupant="nobody — sealed since the dye-works closed",
         desc="A long stone vault with old vats and strange stains. Thick walls, fit to hold arcane energies.", becomes="an arcane foundry"),
    dict(id="apartment", name="The Ashby Apartment", rooms=["living", "bedroom", "storage", "pantry"], price=700, occupant="the Ashby family",
         desc="A proper home: a living room with a hearth, a bedroom, storage and a pantry with a bath.", becomes="your home"),
]

SMITHY_INTERACT = [
    dict(kind="bed", id="player_bed", pos=[28.6, 9.6], r=120, label="Your bed — sleep until morning (autosave)"),
    dict(kind="bed", id="cot", pos=[20.4, 11.0], r=100, label="Your cot — sleep until morning (autosave)"),
    dict(kind="property", id="deeds", pos=[23.0, 12.4], r=100, label="Deeds, plans & workshop equipment"),
    dict(kind="customize", id="mirror", pos=[20.4, 7.9], r=90, label="Mirror — change your appearance"),
    dict(kind="customize", id="bedroom_mirror", pos=[25.0, 15.4], r=90, label="Mirror — change your appearance"),
    dict(kind="bed", id="armchair", pos=[26.6, 1.9], r=90, label="Sit by the hearth — rest"),
    dict(kind="ledger", id="study_desk", pos=[22.8, 9.8], r=110, label="Your ledger — accounts, journal & upgrades"),
    dict(kind="counter", id="smithy", pos=[14.5, 3.6], r=150, label="Shop counter — stock, customers & ledger"),
]

# ======================================================================= the inn
INN_ROOMS = [
    room("common", "Common Room", [0, 0, 14, 14], "floor_tavern"),
    room("kitchen", "Kitchen", [14, 0, 6, 7], "floor_stone"),
    room("hilde_room", "Hilde's Room", [14, 7, 6, 7], "floor_wood", None, "wall_plaster"),
]
INN_DOORS = [door("common", "kitchen", 3), door("common", "hilde_room", 10)]
INN_FURNITURE = [
    F("bar_counter", 6.0, 3.0), F("bar_shelf", 6.0, 0.55), F("keg", 2.4, 1.2), F("keg", 9.6, 1.2),
    F("fireplace", 1.0, 7.0, 270), F("rug_red", 7.4, 8.8),
    F("table_round", 4.4, 6.6), F("table_round", 9.4, 6.2), F("table_round", 4.0, 11.0), F("table_round", 8.8, 10.6),
    F("table_long", 11.4, 12.7), F("bench", 11.4, 11.6), F("table_round", 11.6, 4.4),
    F("kitchen_stove", 17.0, 1.0), F("cupboard", 19.4, 3.6, 90), F("barrel", 15.0, 6.2), F("produce_crate", 18.6, 6.0),
    F("bed", 18.8, 9.6), F("dresser", 15.4, 13.4), F("nightstand", 17.4, 8.4), F("chest", 15.2, 9.0),
    F("most_wanted_board", 2.8, 13.45),
]
INN_INTERACT = [dict(kind="wanted", id="inn", pos=[2.8, 12.7], r=150, label="The MOST WANTED board — Brindlewick's adventurers")]
INN_TABLES = [[4.4, 6.6], [9.4, 6.2], [4.0, 11.0], [8.8, 10.6], [11.4, 12.7], [11.6, 4.4]]
INN_SPOTS = {"inn_bar": [6.0, 4.3], "inn_behind_bar": [6.0, 1.9], "inn_hearth": [2.2, 8.6], "inn_inside": [10.0, 12.6],
             "inn_kitchen": [16.6, 3.4], "hilde_bed": [17.0, 10.6]}

UPSTAIRS_ROOMS = [
    room("landing", "Landing", [0, 5, 12, 4], "floor_wood"),
    room("guest_1", "Guest Room I", [0, 0, 6, 5], "floor_wood", None, "wall_plaster"),
    room("guest_2", "Guest Room II", [6, 0, 6, 5], "floor_wood", None, "wall_plaster"),
    room("guest_3", "Guest Room III", [0, 9, 6, 5], "floor_wood", None, "wall_plaster"),
    room("guest_4", "Guest Room IV", [6, 9, 6, 5], "floor_wood", None, "wall_plaster"),
    room("velvet_parlour", "The Velvet Lantern — Parlour", [12, 0, 8, 9], "floor_tavern", [1.0, 0.9, 0.9]),
    room("velvet_a", "The Velvet Lantern — Rose Room", [12, 9, 4, 5], "floor_tavern", [1.0, 0.88, 0.88]),
    room("velvet_b", "The Velvet Lantern — Amber Room", [16, 9, 4, 5], "floor_tavern", [1.0, 0.92, 0.84]),
]
UPSTAIRS_DOORS = [door("landing", "guest_1", 2), door("landing", "guest_2", 8), door("landing", "guest_3", 2),
                  door("landing", "guest_4", 8), door("landing", "velvet_parlour", 6), door("velvet_parlour", "velvet_a", 13),
                  door("velvet_parlour", "velvet_b", 17)]
UPSTAIRS_FURNITURE = [
    F("bed", 1.4, 2.4), F("nightstand", 3.0, 0.8), F("bed", 10.6, 2.4), F("chest", 7.2, 3.8),
    F("bed", 1.4, 11.6), F("chest", 4.6, 12.8), F("bed", 10.6, 11.6), F("nightstand", 7.0, 12.6),
    F("rug_red", 16.0, 4.4, 90), F("table_round", 15.0, 4.4), F("chair", 14.0, 4.4), F("chair", 16.0, 4.4),
    F("bar_shelf", 16.0, 0.55), F("candle", 15.0, 4.2), F("candle", 19.2, 2.0),
    F("bed_fancy", 14.0, 11.8), F("bed_fancy", 18.0, 11.8),
]
UPSTAIRS_SPOTS = {"lantern_1": [13.4, 6.8], "lantern_2": [17.0, 6.8], "lantern_3": [18.6, 3.0], "upstairs_hall": [6.0, 7.0]}

# ======================================================================= grocer & homes
GROCERY_ROOMS = [room("g_shop", "Pell's Provisions", [0, 4, 7, 5], "floor_wood"),
                 room("g_store", "Storeroom", [7, 4, 4, 5], "floor_stone"),
                 room("g_living", "The Pells' Rooms", [0, 0, 11, 4], "floor_wood", None, "wall_plaster")]
GROCERY_DOORS = [door("g_shop", "g_store", 6), door("g_shop", "g_living", 1)]
GROCERY_FURNITURE = [F("shop_counter", 3.6, 5.6), F("produce_crate", 0.9, 7.8), F("produce_crate", 2.0, 8.1),
                     F("grain_sacks", 6.3, 5.0), F("shelf", 6.4, 8.6), F("crate", 9.0, 5.0), F("crate", 10.2, 6.4),
                     F("sack", 10.3, 5.0), F("barrel", 10.2, 8.2), F("ingredient_crates", 9.0, 8.2),
                     F("bed", 9.6, 1.6), F("bed", 7.6, 1.6), F("table_round", 3.4, 2.0), F("chair", 2.4, 2.0),
                     F("kitchen_stove", 0.9, 1.0, 90), F("candle", 3.4, 1.8)]
GROCERY_SPOTS = {"grocery_behind": [3.6, 4.7], "grocery_front": [3.6, 6.9], "grocery_home": [4.6, 2.6]}


def home(bid, w, h, front_side, extras, workshop=False):
    split = 6 if w >= 9 else 5
    rooms = [room(bid + "_main", "Workshop" if workshop else "Main Room", [0, 0, split, h], "floor_wood"),
             room(bid + "_bed", "Bedroom", [split, 0, w - split, h], "floor_wood", None, "wall_plaster")]
    doors = [door(bid + "_main", bid + "_bed", 2, 2)]
    furn = [F("bed", split + (w - split) / 2, 1.6), F("chest", w - 0.9, h - 1.0), F("nightstand", w - 0.5, 3.8),
            F("table_round", split * 0.5, h * 0.6), F("chair", split * 0.5 - 0.95, h * 0.6), F("shelf", split * 0.5, 0.55),
            F("candle", split * 0.5, h * 0.58), F("kitchen_stove", 0.9, 1.2, 90)] + extras
    spots = {bid + "_inside": [split * 0.5 + 1.0, h * 0.7], bid + "_bedside": [split + (w - split) / 2, 4.0]}
    return rooms, doors, furn, spots


layout = json.load(open(os.path.join(D, "layout.json")))
by_id = {b["id"]: b for b in layout["buildings"]}

s = by_id["smithy"]
s.update(rect=[18, 34, 30, 23], doors=[{"side": "n", "at": 13, "w": 2}], chimneys=[[1, 1], [27, 0], [11, 15]],
         rooms=SMITHY_ROOMS, room_doors=SMITHY_DOORS, furniture=SMITHY_FURNITURE, spots=SMITHY_SPOTS,
         interact=SMITHY_INTERACT, station_pos=SMITHY_STATIONS, customer_rooms=["shop"], units=SMITHY_UNITS,
         locked_rooms=["shop"], entrance=[14.0, 0.6],
         starter_stations=["forge", "anvil", "crucible", "quench_trough", "grinding_wheel"])

i = by_id["inn"]
i.update(rooms=INN_ROOMS, room_doors=INN_DOORS, furniture=INN_FURNITURE, spots=INN_SPOTS, tables=INN_TABLES, interact=INN_INTERACT,
         stairs={"pos": [12.6, 1.6], "to": "inn_upstairs"})

g = by_id["grocery"]
g.update(rooms=GROCERY_ROOMS, room_doors=GROCERY_DOORS, furniture=GROCERY_FURNITURE, spots=GROCERY_SPOTS)

for bid, extras, ws in [("house_martha", [F("rug_brown", 2.6, 4.6), F("washtub", 1.2, 6.6)], False),
                        ("house_tobin", [F("workbench", 2.6, 6.4), F("woodpile", 4.8, 1.2)], True),
                        ("house_jory", [F("grain_sacks", 1.2, 6.4), F("produce_crate", 4.6, 6.6)], False),
                        ("house_eda", [F("washtub", 1.4, 5.6)], False),
                        ("house_wenna", [F("rug_red", 3.0, 4.0)], False)]:
    b = by_id[bid]
    rr, dd, ff, sp = home(bid, b["rect"][2], b["rect"][3], b["doors"][0]["side"], extras, ws)
    b.update(rooms=rr, room_doors=dd, furniture=ff, spots=sp)

ch = by_id["house_oswin"]
ch.update(rooms=[room("nave", "Nave", [0, 0, 7, 9], "floor_stone", None, "wall_stone"),
                 room("vestry", "Vestry", [7, 0, 3, 9], "floor_wood", None, "wall_plaster")],
          room_doors=[door("nave", "vestry", 1)],
          furniture=[F("altar", 6.2, 4.5, 90), F("pew", 3.0, 2.0), F("pew", 3.0, 3.4), F("pew", 3.0, 5.6), F("pew", 3.0, 7.0),
                     F("bed", 8.5, 6.6), F("bookshelf", 8.5, 0.55), F("candle", 6.2, 3.2), F("candle", 6.2, 5.8)],
          spots={"house_oswin_inside": [5.2, 4.5], "oswin_bed": [8.5, 4.0]})

up = [a for a in layout["areas"] if a["id"] == "inn_upstairs"][0]
up.update(rooms=UPSTAIRS_ROOMS, room_doors=UPSTAIRS_DOORS, furniture=UPSTAIRS_FURNITURE, spots=UPSTAIRS_SPOTS,
          stairs={"pos": [0.8, 7.0], "to": "inn"})

# road into the new smithy door (north wall, x = 18 + 13..15)
for r in layout["roads"]:
    if r["id"] == "lane_smithy":
        r["points"] = [[32.0, 31.2], [32.0, 34.2]]

json.dump(layout, open(os.path.join(D, "layout.json"), "w"), indent=1)
print("layout ok")
