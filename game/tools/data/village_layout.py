"""Iteration 009 village layout, applied by make_layout.py after the base buildings (never touches the smithy).

Adds the new buildings (herbalist, Barnaby's house + the Ironfront basement area, a chandler, a stable, a cooper,
two cottages, a net loft), the pond, the harbour/estuary, the outdoor dressing (groves, woodland boundary,
fields, hedges, walls, grit) and richer clutter in the existing interiors. Everything is data in layout.json:

  buildings[].stairways  [{pos, to, arrive, sprite, label}]   generic stairs (world.gd `_build_stairways`)
  pond                   {center, radius, jetty, reeds, ducks, bench}
  harbour                {water, quay, jetty, ship, booth, posts, culvert}
  groves                 [[x, y, r, density]]   clustered trees with undergrowth
  boundary               {depth, keep_clear}    dense woodland belt along the map edge
  outdoor_props          [[prop, x, y, rot]]    hand-placed dressing (fences, hedges, grit, harbour clutter)
  outdoor_spots          {name: [x, y]}         outdoor NPC spots (pond_1..3, harbour_quay, ...)
All coordinates are tiles (64 px)."""


def apply(layout, by_id, room, door, F, home):
    def ensure(bid, **base):
        """Adds a building if missing, or refreshes its base fields (rect, roof, doors...)."""
        b = by_id.get(bid)
        if b is None:
            b = {"id": bid}
            layout["buildings"].append(b)
            by_id[bid] = b
        b.update(base)
        return b

    # ------------------------------------------------------------------ areas off the map
    # the areas' dim timber frame reaches 14 tiles beyond their rect: keep them clear of the 96-tile map
    up = [a for a in layout["areas"] if a["id"] == "inn_upstairs"][0]
    up["rect"] = [118, 10, 20, 14]
    up["furniture"] = up["furniture"] + [
        F("rug_brown", 3.6, 2.6), F("chair", 4.8, 0.9), F("washtub", 4.8, 3.8),
        F("rug_brown", 8.6, 2.6), F("chair", 8.0, 0.9), F("candle", 7.2, 3.6),
        F("rug_brown", 3.4, 11.4), F("chair", 4.8, 10.0), F("washtub", 1.0, 13.2),
        F("rug_brown", 8.4, 11.4), F("chair", 7.2, 10.0), F("candle", 7.0, 12.4),
        F("bench", 4.0, 5.6), F("barrel", 10.9, 8.4), F("candle", 11.0, 5.5),
        F("standing_lamp", 12.7, 0.8), F("standing_lamp", 19.3, 8.3), F("rug_red", 16.0, 1.6),
    ]
    if not any(a["id"] == "ironfront_basement" for a in layout["areas"]):
        layout["areas"].append({"id": "ironfront_basement"})
    bs = [a for a in layout["areas"] if a["id"] == "ironfront_basement"][0]
    bs.update(name="Barnaby's Basement — The Ironfront Den", rect=[118, 34, 13, 10], floor="floor_slate",
              rooms=[room("den", "The Ironfront Den", [0, 0, 9, 10], "floor_tavern", [0.96, 0.92, 0.86], "wall_stone"),
                     room("card_archive", "Barnaby's Card Archive", [9, 0, 4, 5], "floor_wood", None, "wall_stone"),
                     room("cellar_stores", "Cellar Stores", [9, 5, 4, 5], "floor_stone", None, "wall_stone")],
              room_doors=[door("den", "card_archive", 2), door("den", "cellar_stores", 7)],
              furniture=[
                  F("felt_table", 4.5, 5.2), F("chair", 3.4, 3.45), F("chair", 5.6, 3.45),
                  F("chair", 3.4, 6.95, 180), F("chair", 5.6, 6.95, 180),
                  F("war_map_wall", 4.0, 0.42), F("diagram_board", 7.2, 0.42), F("tank_shelf", 0.42, 4.6, 90),
                  F("tank_shelf", 0.42, 7.2, 90), F("diagram_board", 8.58, 5.5, 90), F("diorama_table", 2.2, 8.9),
                  F("paint_desk", 6.6, 9.35), F("standing_lamp", 0.95, 3.0), F("standing_lamp", 8.2, 2.6),
                  F("standing_lamp", 8.2, 8.0), F("crate", 8.4, 9.45), F("rug_brown", 7.4, 7.6),
                  F("card_cabinet", 11.0, 0.45), F("card_binders", 12.55, 2.6, 90), F("bookshelf", 10.6, 4.55), F("chest", 12.2, 4.3),
                  F("candle", 12.2, 4.1),
                  F("barrel", 12.5, 5.7), F("barrel", 12.5, 6.6), F("crate_stack", 12.2, 9.2), F("crate", 10.0, 9.5),
                  F("crate", 10.9, 9.5), F("sack", 11.0, 7.9), F("woodpile", 10.6, 5.6)],
              spots={"ironfront_host": [4.5, 3.3], "ironfront_player": [4.5, 7.1], "ironfront_den": [7.6, 3.4],
                     "ironfront_archive": [10.8, 2.4]},
              interact=[dict(kind="ironfront", id="table", pos=[4.5, 5.2], r=210,
                             label="Barnaby's Ironfront table — sit down for a match")],
              stairways=[dict(pos=[1.0, 1.4], to="barnaby_house", arrive=[2.4, 2.6], sprite="stairs_up",
                              label="Stairs — up to Barnaby's parlour")])

    # ------------------------------------------------------------------ new buildings
    hb = ensure("herbalist", name="Fennimore's Simples", rect=[47, 17, 9, 7], roof="thatch", ridge="h", floor="floor_herb",
                doors=[{"side": "s", "at": 3, "w": 2}], chimneys=[[7, 1]])
    hb.update(rooms=[room("h_shop", "Fennimore's Simples", [0, 0, 6, 7], "floor_herb", [1.0, 0.98, 0.92]),
                     room("h_drying", "Drying Room", [6, 0, 3, 7], "floor_wood", None, "wall_plaster")],
              room_doors=[door("h_shop", "h_drying", 4)],
              furniture=[F("herb_counter", 3.0, 2.6), F("jar_shelf", 1.5, 0.42), F("jar_shelf", 4.5, 0.42),
                         F("herb_baskets", 0.85, 5.0, 90), F("rug_brown", 3.0, 5.0), F("candle", 4.7, 2.4),
                         F("herb_garlands", 3.0, 1.2), F("bottle_shelf", 5.55, 4.6, 90), F("sack", 5.4, 6.3),
                         F("herb_rack", 7.5, 0.42), F("herb_garlands", 7.5, 3.4, 90), F("ingredient_crates", 7.5, 5.9),
                         F("potting_bench", 7.6, 2.0), F("sack", 8.5, 4.4)],
              spots={"herbalist_counter": [3.0, 1.45], "herbalist_inside": [2.4, 4.4]},
              interact=[dict(kind="herbalist", id="herbalist", pos=[3.0, 3.3], r=140,
                             label="Herbalist's counter — herbs, remedies & reagents")])

    bh = ensure("barnaby_house", name="Barnaby's House", rect=[46, 3, 10, 7], roof="clay", ridge="h", floor="floor_wood",
                doors=[{"side": "s", "at": 3, "w": 1}], chimneys=[[8, 1]])
    bh.update(rooms=[room("b_parlour", "Barnaby's Parlour", [0, 0, 6, 7], "floor_wood"),
                     room("b_bed", "Barnaby's Bedroom", [6, 0, 4, 7], "floor_wood", None, "wall_plaster")],
              room_doors=[door("b_parlour", "b_bed", 4)],
              furniture=[F("table_round", 4.0, 3.4), F("chair", 3.0, 3.4), F("candle", 4.0, 3.2), F("bookshelf", 4.0, 0.42),
                         F("card_binders", 5.55, 2.4, 90), F("rug_brown", 3.6, 3.6), F("kitchen_stove", 0.9, 5.4, 90),
                         F("barrel", 0.7, 6.4), F("war_map_wall", 2.8, 6.55, 180),
                         F("bed", 8.0, 1.6), F("nightstand", 9.5, 0.6), F("paint_desk", 8.0, 4.6), F("chest", 9.1, 6.3),
                         F("tank_shelf", 9.55, 3.2, 90)],
              spots={"barnaby_house_inside": [2.6, 4.6], "barnaby_bed": [8.0, 3.3]},
              stairways=[dict(pos=[1.2, 1.4], to="ironfront_basement", arrive=[2.6, 3.0], sprite="stairs_down",
                              label="Stairs — down to Barnaby's basement (the Ironfront den)")])

    chd = ensure("chandler", name="Wick & Tallow Chandlery", rect=[63, 9, 9, 7], roof="slate", ridge="h", floor="floor_wood",
                 doors=[{"side": "s", "at": 2, "w": 1}], chimneys=[[7, 1]])
    chd.update(rooms=[room("c_shop", "Wick & Tallow Chandlery", [0, 0, 5, 7], "floor_wood"),
                      room("c_work", "Dipping Room", [5, 0, 4, 7], "floor_stone", [1.0, 0.95, 0.88], "wall_stone")],
               room_doors=[door("c_shop", "c_work", 4)],
               furniture=[F("candle_rack", 1.4, 0.42), F("shelf", 3.6, 0.42), F("table_round", 2.6, 3.4), F("candle", 2.3, 3.2),
                          F("candle", 2.9, 3.5), F("crate", 0.6, 6.3), F("sack", 0.6, 5.4), F("candle_rack", 0.42, 3.0, 90),
                          F("wax_vat", 7.0, 2.2), F("candle_rack", 7.0, 6.55, 180), F("barrel", 8.4, 4.6), F("sack", 5.7, 6.3),
                          F("woodpile", 7.4, 0.6)],
               spots={"chandler_inside": [3.4, 5.0]})

    ensure("house_fenn", name="Fenn Cottage", rect=[75, 9, 8, 6], roof="thatch", ridge="h", floor="floor_wood",
           doors=[{"side": "s", "at": 2, "w": 1}], chimneys=[[1, 1]])
    ensure("house_ashby", name="Ashby Cottage", rect=[50, 48, 7, 6], roof="thatch", ridge="v", floor="floor_wood",
           doors=[{"side": "n", "at": 2, "w": 1}], chimneys=[[5, 4]])

    stb = ensure("stable", name="Brindle Stable", rect=[1, 24, 6, 5], roof="thatch", ridge="v", floor="floor_wood",
                 doors=[{"side": "e", "at": 1, "w": 2}], chimneys=[])
    stb.update(rooms=[room("stalls", "Brindle Stable", [0, 0, 6, 5], "floor_wood", [1.0, 0.95, 0.85])], room_doors=[],
               furniture=[F("horse", 1.1, 2.4), F("horse", 2.7, 2.6), F("water_trough", 2.0, 4.55), F("saddle_rack", 4.3, 0.42),
                          F("haybale", 5.3, 4.3), F("haybale", 4.4, 4.4), F("mud_patch", 2.0, 2.6), F("fence_v", 1.9, 1.4),
                          F("fence_v", 1.9, 2.4)],
               spots={"stable_inside": [4.6, 2.6]})

    cop = ensure("cooperage", name="Coopers' Workshop", rect=[50, 39, 7, 6], roof="clay", ridge="v", floor="floor_wood",
                 doors=[{"side": "e", "at": 2, "w": 2}], chimneys=[[1, 1]])
    cop.update(rooms=[room("co_store", "Stave Store", [0, 0, 3, 6], "floor_stone"),
                      room("co_work", "Coopers' Workshop", [3, 0, 4, 6], "floor_wood")],
               room_doors=[door("co_store", "co_work", 2)],
               furniture=[F("workbench", 5.0, 0.6), F("barrel_stack", 5.2, 4.9), F("hoop_pile", 4.0, 3.2), F("stave_bundle", 1.5, 0.5),
                          F("stave_bundle", 1.5, 1.4), F("woodpile", 1.4, 5.3), F("barrel", 0.6, 3.6), F("chopping_block", 3.6, 5.3)],
               spots={"cooper_inside": [4.6, 2.6]})

    nl = ensure("net_loft", name="Net Loft", rect=[79, 47, 6, 4], roof="slate", ridge="h", floor="floor_wood",
                doors=[{"side": "s", "at": 2, "w": 1}], chimneys=[])
    nl.update(rooms=[room("loft", "Net Loft", [0, 0, 6, 4], "floor_wood", [0.96, 0.96, 0.98])], room_doors=[],
              furniture=[F("net_pile", 1.2, 0.9), F("lobster_pots", 4.8, 0.8), F("rope_coil", 3.2, 1.0), F("barrel", 5.3, 3.2),
                         F("crate", 0.6, 3.3), F("anchor", 3.0, 2.2)],
              spots={"net_loft_inside": [3.6, 2.8]})

    # Eda's door faces the lane on its south side (the old lane ran to a wall)
    by_id["house_eda"]["doors"] = [{"side": "s", "at": 4, "w": 1}]

    # ------------------------------------------------------------------ homes: furniture + clutter
    homes = [
        ("house_martha", [F("rug_brown", 2.6, 4.6), F("washtub", 1.2, 6.6), F("cupboard", 5.45, 1.9, 90), F("sack", 0.7, 3.4),
                          F("rug_brown", 7.5, 4.9), F("herb_garlands", 3.0, 2.0), F("candle", 1.0, 5.0)], False),
        ("house_tobin", [F("workbench", 2.6, 6.4), F("woodpile", 4.8, 1.2), F("crate", 0.7, 3.4), F("barrel", 5.4, 3.2),
                         F("chopping_block", 0.75, 5.1), F("broken_crate", 5.3, 6.9)], True),
        ("house_jory", [F("grain_sacks", 1.2, 6.4), F("produce_crate", 4.6, 6.6), F("sack", 0.7, 4.0), F("barrel", 5.45, 2.6),
                        F("haybale", 5.5, 5.0), F("rug_brown", 8.0, 5.2)], False),
        ("house_eda", [F("washtub", 1.4, 5.6), F("cupboard", 4.5, 1.9, 90), F("sack", 0.6, 3.0), F("herb_garlands", 2.5, 1.4),
                       F("rug_red", 6.5, 4.8)], False),
        ("house_wenna", [F("rug_red", 3.0, 4.0), F("barrel", 5.4, 5.9), F("barrel", 0.7, 5.9), F("stave_bundle", 2.6, 6.4),
                         F("hoop_pile", 4.6, 6.0)], False),
        ("house_fenn", [F("rug_brown", 2.4, 3.4), F("sack", 4.4, 5.2), F("washtub", 0.8, 5.0)], False),
        ("house_ashby", [F("rug_red", 2.5, 3.6), F("barrel", 4.4, 5.3), F("herb_garlands", 2.5, 1.2)], False),
    ]
    for bid, extras, ws in homes:
        b = by_id[bid]
        rr, dd, ff, sp = home(bid, b["rect"][2], b["rect"][3], b["doors"][0]["side"], extras, ws)
        b.update(rooms=rr, room_doors=dd, furniture=ff, spots=sp)

    # inn, grocer and chapel: more lived-in clutter on top of their base furniture
    inn = by_id["inn"]
    inn["furniture"] = inn["furniture"] + [
        F("stool", 3.4, 6.65), F("stool", 5.4, 6.65), F("stool", 8.4, 6.25), F("stool", 10.4, 6.25), F("stool", 3.0, 11.05),
        F("stool", 5.0, 11.05), F("stool", 7.8, 10.65), F("stool", 9.8, 10.65), F("stool", 10.6, 4.45), F("stool", 12.6, 4.45),
        F("woodpile", 0.9, 10.0, 90), F("barrel", 0.6, 2.6), F("barrel", 0.6, 3.5), F("sack", 13.3, 8.6), F("candle", 4.6, 2.9),
        F("candle", 7.6, 2.9), F("mud_patch", 10.0, 13.1), F("chair", 13.3, 6.4, 90), F("broken_crate", 13.2, 11.0),
        F("washtub", 15.2, 1.2), F("grain_sacks", 17.0, 6.3), F("herb_rack", 17.6, 0.42), F("sack", 19.4, 6.4),
        F("rug_brown", 17.0, 11.6), F("candle", 17.4, 8.3), F("wardrobe", 19.6, 12.6, 90)]
    gr = by_id["grocery"]
    gr["furniture"] = gr["furniture"] + [
        F("barrel", 0.6, 6.3), F("herb_baskets", 6.2, 7.2, 90), F("mud_patch", 4.9, 8.3), F("rug_brown", 5.2, 2.4),
        F("sack", 7.6, 7.0), F("crate", 8.6, 6.6), F("cupboard", 0.42, 2.6, 90)]
    chp = by_id["house_oswin"]
    chp["furniture"] = chp["furniture"] + [
        F("rug_red", 4.4, 4.5, 90), F("candle", 0.6, 1.0), F("candle", 0.6, 8.0), F("candle", 6.6, 1.2), F("candle", 6.6, 7.8),
        F("chest", 8.6, 8.2), F("candle", 8.5, 2.2)]

    # ------------------------------------------------------------------ roads & lanes
    roads = {r["id"]: r for r in layout["roads"]}

    def road(rid, width, pts):
        if rid in roads:
            roads[rid].update(width=width, points=pts)
        else:
            r = {"id": rid, "width": width, "points": pts}
            layout["roads"].append(r)
            roads[rid] = r

    # lane_se now serves Eda's door (south side) and runs on to the harbour
    road("lane_se", 1.4, [[59.2, 44.4], [64, 44.3], [68.5, 44.3], [73, 44.7], [76.6, 45.8], [77.4, 49.6], [79.0, 52.0]])
    road("lane_north", 1.2, [[58.7, 12.6], [52, 12.9], [46, 12.6], [40, 12.1], [34, 12.3], [27, 12.0], [21, 12.6]])
    road("lane_ne", 1.2, [[59.1, 17.2], [66.5, 17.0], [72, 17.2], [77.5, 16.8], [77.5, 15.6]])
    road("lane_herbalist", 1.0, [[51.0, 25.2], [51.6, 28.0], [54.0, 30.4]])
    road("lane_farm", 1.1, [[13.0, 31.4], [11.6, 35.0], [8.5, 38.9]])
    road("lane_wenna", 1.0, [[78.0, 31.0], [80.6, 34.0], [82.5, 36.9]])
    road("lane_stable", 1.0, [[12.0, 26.0], [10.2, 26.2], [8.4, 26.0]])
    road("lane_ashby", 1.0, [[58.9, 46.8], [55, 46.9], [52.5, 47.0]])
    road("lane_cooper", 1.0, [[58.7, 42.0], [57.2, 42.0]])
    road("lane_graveyard", 0.9, [[59.3, 57.6], [64.6, 57.8]])

    # the stream now ends in the harbour estuary (south-east)
    layout["stream"]["points"] = [[90, -1], [88.5, 14], [90.5, 31], [89, 44], [89.6, 52.4]]

    # ------------------------------------------------------------------ pond & harbour
    layout["pond"] = {"center": [36.0, 7.4], "radius": [4.6, 2.9], "jetty": [38.1, 6.6, 1.0, 3.6],
                      "bench": [33.3, 10.55], "ducks": [[34.2, 6.6], [35.4, 8.2], [37.0, 5.6]],
                      "reeds": [[31.4, 6.8], [31.8, 5.6], [32.6, 4.8], [34.0, 4.4], [39.4, 4.5], [40.6, 5.4], [41.0, 7.2],
                                [40.6, 8.7], [32.2, 8.9]],
                      "lilies": [[34.0, 7.6], [39.4, 7.0]]}
    layout["harbour"] = {
        "water": [[75.8, 53.6], [79, 53.25], [84, 53.3], [88.6, 53.1], [89.6, 52.6], [90.6, 53.1], [94, 53.25], [101.5, 53.4],
                  [101.5, 69], [75.0, 69], [75.4, 65.2], [76.1, 61.2], [75.6, 58.0], [76.0, 55.6]],
        "quay": [75.6, 51.0, 26.0, 2.4],
        "jetty": [83.2, 53.0, 1.6, 6.2],
        "ship": [90.8, 55.5],
        "booth": [86.8, 50.3],
        "boats": [[86.0, 57.4], [82.0, 55.0]],
        "posts": [[77.4, 53.25], [80.6, 53.25], [82.6, 53.25], [86.0, 53.25], [95.2, 53.25], [83.4, 59.0], [84.6, 59.0],
                  [83.4, 56.0], [84.6, 56.0]],
        "culvert": [89.6, 51.0, 1.5, 2.4],
    }

    # ------------------------------------------------------------------ vegetation & boundaries
    layout["groves"] = [[12, 8, 4.0, 1.0], [24.5, 5.5, 2.6, 0.9], [44, 3.5, 2.2, 0.8], [70, 4, 3.0, 1.0], [86, 10, 3.6, 1.0],
                        [72.5, 31.5, 2.2, 0.7], [62.5, 59.5, 2.4, 0.9], [44, 60.4, 3.0, 1.0], [30, 60.5, 3.0, 1.0],
                        [16.5, 61, 2.2, 0.8], [3, 61, 2.4, 1.0], [94, 40, 2.6, 1.0], [16.8, 8.6, 1.6, 0.7], [8, 3, 3, 1.0], [5.2, 35.2, 1.8, 0.9]]
    layout["boundary"] = {"depth": 3.6, "spacing": 1.25,
                          "keep_clear": [[54, -2, 10, 8], [-2, 27, 7, 9], [89, 27, 9, 8], [54, 57, 10, 9], [75, 46, 13, 20], [75, 50, 30, 20]]}
    props = []
    # Jory's fields south of the farm fence, edged with hedges
    for y in (51.4, 53.6, 55.8):
        for x in (3.6, 6.8, 10.0, 13.2):
            props.append(F("crop_rows", x, y))
    for x in range(2, 16, 2):
        props.append(F("hedge_h", x + 1.0, 57.6))
    for y in range(50, 58, 2):
        props.append(F("hedge_v", 15.8, y + 1.0))
    props += [F("haybale", 2.6, 50.4), F("cart", 14.0, 50.4), F("dummy_target", 8.6, 54.7)]
    # graveyard south of the chapel inside a dry-stone wall
    for x in range(65, 75, 2):
        props.append(F("stone_wall_h", x + 1.0, 62.5))     # south wall
    for x in range(67, 75, 2):
        props.append(F("stone_wall_h", x + 1.0, 56.6))     # north wall (gate at the west end, by the lane)
    for y in (58.0, 60.0):
        props.append(F("stone_wall_v", 74.9, y + 0.9))
    props.append(F("stone_wall_v", 64.8, 61.4))
    for i, (x, y) in enumerate([(66.6, 58.4), (68.2, 58.6), (69.8, 58.3), (71.4, 58.5), (73.0, 58.4), (66.8, 60.6),
                                (68.4, 60.8), (70.0, 60.5), (71.6, 60.7), (73.2, 60.6)]):
        props.append(F("gravestone", x, y))
    props += [F("tree_pine", 73.6, 61.4), F("bush", 66.2, 61.8)]
    # hedges and fences giving the cottages gardens
    props += [F("hedge_h", 76.0, 15.6), F("hedge_h", 82.0, 15.6), F("hedge_v", 74.5, 12.6), F("hedge_v", 83.6, 12.6),
              F("hedge_h", 47.8, 10.9), F("hedge_v", 45.5, 7.0), F("fence_h", 4.5, 30.0), F("fence_h", 5.5, 30.0),
              F("fence_h", 2.5, 30.0), F("fence_h", 1.5, 30.0), F("herb_garden", 45.4, 21.0), F("herb_garden", 45.4, 18.8),
              F("stone_wall_v", 0.6, 20.6), F("stone_wall_v", 0.6, 17.6)]
    # grit: mud, puddles, refuse, firewood, broken crates, carts — by doors, yards and the busy roads
    props += [F("puddle", 27.0, 31.6), F("puddle", 46.5, 31.9), F("puddle", 61.4, 37.8), F("puddle", 71.6, 30.3),
              F("puddle", 58.6, 49.0), F("puddle", 9.6, 32.0), F("puddle", 84.0, 31.4), F("puddle", 58.4, 8.0),
              F("mud_patch", 8.4, 25.8), F("mud_patch", 34.0, 29.4), F("mud_patch", 67.4, 29.0), F("mud_patch", 62.0, 35.6),
              F("mud_patch", 80.6, 51.9), F("mud_patch", 50.6, 26.0), F("mud_patch", 15.0, 30.4), F("mud_patch", 59.0, 61.0),
              F("refuse_heap", 44.8, 27.2), F("refuse_heap", 73.2, 27.0), F("refuse_heap", 3.4, 39.0), F("refuse_heap", 71.2, 15.4),
              F("broken_crate", 45.6, 25.6), F("broken_crate", 74.6, 22.4), F("broken_crate", 62.2, 26.6), F("broken_crate", 92.4, 52.4),
              F("woodpile", 13.8, 21.6, 90), F("woodpile", 85.6, 22.0, 90), F("woodpile", 72.6, 39.0, 90), F("woodpile", 56.6, 5.6, 90),
              F("chopping_block", 14.2, 23.4), F("chopping_block", 86.2, 24.2), F("chopping_block", 73.0, 41.0),
              F("barrel", 62.4, 27.4), F("barrel", 74.6, 20.0), F("barrel", 44.6, 15.0), F("sack", 61.8, 18.4), F("crate", 62.2, 19.6),
              F("cart", 47.0, 28.4), F("haybale", 8.0, 29.0), F("water_trough", 9.5, 23.9), F("stump", 26.0, 9.8),
              F("stump", 79.0, 36.0), F("stump", 3.2, 45.0), F("rock_a", 20.6, 15.0), F("rock_b", 87.0, 33.6)]
    # moss creeping along the shaded north walls of the older houses
    for bid in ["inn", "grocery", "house_martha", "house_tobin", "house_oswin", "house_jory", "house_eda", "house_wenna", "chandler",
                "herbalist", "barnaby_house"]:
        r = by_id[bid]["rect"]
        props.append(F("moss_decal", r[0] + 1.2, r[1] - 0.15))
        props.append(F("moss_decal", r[0] + r[2] - 1.4, r[1] - 0.15))
    # harbour clutter
    props += [F("crate_stack", 94.6, 52.0), F("barrel", 93.0, 51.7), F("barrel", 92.4, 52.6), F("net_rack", 93.0, 49.6),
              F("lobster_pots", 95.4, 50.6), F("net_pile", 91.8, 50.4), F("rope_coil", 82.2, 52.6), F("rope_coil", 85.0, 58.2),
              F("anchor", 77.4, 52.4), F("net_rack", 76.4, 48.6, 90), F("crate", 80.0, 51.6), F("sack", 78.6, 51.5),
              F("reeds", 76.2, 54.2), F("reeds", 76.0, 57.6), F("reeds", 76.4, 60.6), F("reeds", 75.8, 63.4)]
    # pond side: a few trees and a fishing rest
    props += [F("rope_coil", 38.6, 9.9), F("barrel", 41.6, 10.6), F("tree_small", 28.6, 9.2), F("tree_oak_b", 42.6, 3.2),
              F("flower_patch_a", 30.6, 10.4), F("flower_patch_b", 41.2, 11.0)]
    layout["outdoor_props"] = props
    layout["outdoor_spots"] = {"pond_1": [33.3, 11.4], "pond_2": [38.6, 10.9], "pond_3": [41.6, 9.0],
                               "harbour_quay": [88.3, 52.3], "graveyard": [66.0, 57.8], "fields": [9.0, 50.4]}

    # ------------------------------------------------------------------ iteration 010: venues, signs, paddocks, lamps
    import village10_layout
    village10_layout.apply(layout, by_id, room, door, F)
