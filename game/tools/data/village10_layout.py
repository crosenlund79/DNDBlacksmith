"""Iteration 010 village layout, applied at the end of village_layout.apply() (never touches the smithy rect).

Adds the new venues (the pawnshop, the rival smith's forge, the Hales' cottage and menagerie yard, the caravan camp,
the ceremony stage on the square, the graveyard plots), paddocks for horses and cows, a sign beside every door and
the street lamps. New layout.json keys (all tiles, read by scripts/world/village10.gd):

  buildings[].sign       sign sprite id (props/<id>), hung beside the first door; buildings[].sign_side -1|1 (left/right)
  lamps                  [[x, y]]                   street lamps (props/street_lamp)
  paddocks               [{id, rect, kind, count, sprites}]   fenced grazing for horses / cows (animals stay inside)
  clearings              [[x, y, w, h]]             nothing grows here (paddocks, yards, the camp, the stage)
  overhead_props         [[prop, x, y, rot]]        drawn above the actors, never solid (bunting, the harbour sign)
  outdoor_interact       [{kind, id, pos, r, label}]
  caravan                {wagon, fire, crates, interact}   the wagon, its crates and interactable only show while
                                                    Commerce.caravan_present() says so (guarded)
"""


def apply(layout, by_id, room, door, F):
    def ensure(bid, **base):
        b = by_id.get(bid)
        if b is None:
            b = {"id": bid}
            layout["buildings"].append(b)
            by_id[bid] = b
        b.update(base)
        return b

    # ================================================================== the pawnshop (east of the square)
    pw = ensure("pawnshop", name="The Three Brass Balls", rect=[73, 32, 7, 5], roof="slate", ridge="h", floor="floor_wood",
                doors=[{"side": "n", "at": 2, "w": 1}], chimneys=[[6, 3]])
    pw.update(rooms=[room("pawn_shop", "The Three Brass Balls — Pawnbroker", [0, 0, 5, 5], "floor_wood", [0.96, 0.92, 0.86]),
                     room("pawn_strong", "Strongroom", [5, 0, 2, 5], "floor_stone", None, "wall_stone")],
              room_doors=[door("pawn_shop", "pawn_strong", 2, 2)],
              furniture=[F("pawn_counter", 2.5, 2.9), F("curio_shelf", 0.42, 2.9, 90), F("curio_shelf", 4.0, 0.42),
                         F("display_case", 0.95, 1.05), F("rug_brown", 2.4, 1.5), F("candle", 3.7, 2.75),
                         F("chest", 6.0, 0.75), F("crate", 6.3, 4.35), F("sack", 5.5, 4.4), F("curio_shelf", 6.58, 2.7, 90),
                         F("candle", 5.6, 1.6)],
              spots={"pawn_counter": [2.5, 4.0], "pawnshop_inside": [1.8, 1.9]},
              interact=[dict(kind="pawn", id="pawn", pos=[2.5, 2.1], r=140,
                             label="Pawnbroker's counter — pawn, sell & buy curios")],
              sign="sign_pawn", sign_side=-1)

    # ================================================================== the rival smith (north lane, by the pond)
    rv = ensure("rival_forge", name="Cinderwell Forge", rect=[21, 3, 9, 6], roof="slate", ridge="h", floor="floor_soot",
                doors=[{"side": "s", "at": 6, "w": 2}], chimneys=[[1, 1]])
    rv.update(rooms=[room("rv_forge", "Cinderwell Forge — the rival's smithy", [0, 0, 5, 6], "floor_soot", [1.0, 0.92, 0.84], "wall_stone"),
                     room("rv_shop", "Cinderwell Forge — wares", [5, 0, 4, 6], "floor_wood")],
              room_doors=[door("rv_forge", "rv_shop", 2, 2)],
              furniture=[F("rival_forge", 1.45, 1.25), F("rival_anvil", 2.9, 3.5), F("tool_wall", 3.6, 0.5), F("coal_pile", 0.85, 3.6, 90),
                         F("barrel", 0.65, 5.3), F("iron_bars", 3.9, 5.35), F("soot_decal", 2.4, 2.6),
                         F("rival_counter", 7.0, 2.45), F("weapon_rack", 8.6, 3.9, 90), F("armor_stand", 5.55, 4.0),
                         F("rival_display", 7.0, 0.5), F("candle", 7.6, 2.3)],
              spots={"rival_smith_forge": [2.9, 4.45], "rival_smith_counter": [7.0, 1.4], "rival_forge_inside": [6.3, 4.4]},
              interact=[dict(kind="rival_smith", id="rival_smith", pos=[7.0, 3.35], r=150,
                             label="The rival smith's counter — wares & commissions")],
              sign="sign_rival", sign_side=-1)

    # ================================================================== the Hales: cottage + menagerie yard (north-west)
    hc = ensure("hale_cottage", name="The Hales' Cottage", rect=[13, 4, 7, 5], roof="thatch", ridge="h", floor="floor_wood",
                doors=[{"side": "s", "at": 3, "w": 1}], chimneys=[[5, 1]])
    hc.update(rooms=[room("hc_parlour", "The Hales' Parlour", [0, 0, 4, 5], "floor_wood"),
                     room("hc_study", "Young Hale's Study & Enclosure Notes", [4, 0, 3, 5], "floor_wood", [0.94, 0.94, 1.0], "wall_plaster")],
              room_doors=[door("hc_parlour", "hc_study", 1, 2)],
              furniture=[F("creature_cages", 2.0, 0.45), F("table_round", 1.7, 2.7), F("chair", 0.75, 2.7), F("kitchen_stove", 0.75, 3.9, 90),
                         F("sack", 0.7, 1.2), F("rug_brown", 2.2, 3.4), F("candle", 1.7, 2.55),
                         F("bestiary_desk", 5.5, 0.55), F("bed", 6.2, 3.65), F("candle", 4.5, 4.4)],
              spots={"hale_study": [5.5, 1.55], "hale_cottage_inside": [2.4, 3.6]},
              sign="sign_menagerie", sign_side=1)

    # ================================================================== street signs for every other building
    signs = {"smithy": ("sign_smithy", -1), "inn": ("sign_inn", -1), "grocery": ("sign_grocer", -1), "herbalist": ("sign_herbalist", 1),
             "house_oswin": ("sign_chapel", -1), "barnaby_house": ("sign_barnaby", 1), "cooperage": ("sign_cooper", -1),
             "stable": ("sign_stable", -1), "chandler": ("sign_chandler", 1), "net_loft": ("sign_netloft", -1),
             "house_tobin": ("sign_carpenter", -1), "house_jory": ("sign_farm", 1), "house_eda": ("sign_laundry", -1),
             "house_martha": ("sign_cottage_a", -1), "house_wenna": ("sign_cottage_b", 1), "house_fenn": ("sign_cottage_b", -1),
             "house_ashby": ("sign_cottage_a", 1)}
    for bid, (sid, side) in signs.items():
        if bid in by_id:
            by_id[bid]["sign"] = sid
            by_id[bid]["sign_side"] = side

    # ================================================================== roads to the new venues
    roads = {r["id"]: r for r in layout["roads"]}

    def road(rid, width, pts):
        if rid in roads:
            roads[rid].update(width=width, points=pts)
        else:
            r = {"id": rid, "width": width, "points": pts}
            layout["roads"].append(r)
            roads[rid] = r

    road("lane_wenna", 1.0, [[80.8, 31.0], [81.8, 34.0], [82.5, 36.9]])           # clears the pawnshop's corner
    road("lane_rival", 1.1, [[28.0, 9.9], [28.2, 11.0], [27.8, 12.1]])
    road("lane_hale", 1.0, [[21.0, 12.6], [17.2, 12.3], [16.5, 9.9]])
    road("lane_yard", 0.8, [[17.2, 12.3], [13.6, 12.1], [11.0, 11.6]])
    road("lane_camp", 1.0, [[58.7, 6.2], [61.4, 6.6], [62.6, 5.6]])

    # ================================================================== groves, boundary & dressing make room
    gone = {(12, 8), (16.8, 8.6), (8, 3), (24.5, 5.5), (5.2, 35.2), (72.5, 31.5), (70, 4)}
    layout["groves"] = [g for g in layout["groves"] if (g[0], g[1]) not in gone] + [
        [2.4, 12.2, 1.8, 0.9], [9.0, 1.6, 2.6, 1.0], [74.0, 4.6, 2.2, 1.0], [33.5, 1.6, 2.0, 0.8]]
    bd = layout["boundary"]
    bd["keep_clear"] = bd["keep_clear"] + [[3, 3.6, 18, 9], [20, 2.6, 11, 8], [59, -1, 11, 10], [0.5, 32.5, 8, 8]]
    drop = {("rock_a", 20.6, 15.0), ("stump", 79.0, 36.0), ("woodpile", 13.8, 21.6), ("chopping_block", 14.2, 23.4)}
    props = [p for p in layout["outdoor_props"] if (p[0], p[1], p[2]) not in drop and not (p[0] == "gravestone")]
    props = [p for p in props if not (p[0] in ("tree_pine", "bush") and 65 < p[1] < 75 and 60 < p[2] < 63)]
    props += [F("woodpile", 13.0, 24.0, 90), F("chopping_block", 13.6, 25.6), F("stump", 80.6, 37.2)]

    def fence_run(x0, y0, x1, y1, gaps=()):
        """Fence posts along a straight run (tiles); `gaps` = tile indices left open (gates)."""
        out = []
        if y0 == y1:
            for i in range(int(round(x1 - x0))):
                if i not in gaps:
                    out.append(F("fence_h", x0 + i + 0.5, y0))
        else:
            for i in range(int(round(y1 - y0))):
                if i not in gaps:
                    out.append(F("fence_v", x0, y0 + i + 0.5))
        return out

    # ---- the Hales' menagerie yard: hutch, coops, an arcane enclosure for the strange ones
    props += fence_run(4.0, 4.4, 12.4, 4.4) + fence_run(4.0, 11.2, 12.4, 11.2, gaps=(6, 7)) + fence_run(4.0, 4.4, 4.0, 11.2) \
        + fence_run(12.4, 4.4, 12.4, 11.2)
    props += [F("rabbit_hutch", 5.7, 5.6), F("chicken_coop", 8.6, 5.8), F("chicken_coop", 11.0, 5.6), F("arcane_enclosure", 6.6, 9.2),
              F("water_trough", 10.6, 7.9), F("haybale", 11.5, 9.4), F("sack", 9.4, 8.2), F("mud_patch", 9.6, 9.8),
              F("feed_scatter", 8.6, 7.4), F("feed_scatter", 5.6, 7.4)]
    # ---- the horse paddock between Martha's cottage and the inn (the stable is just west)
    props += fence_run(14.2, 13.8, 20.8, 13.8, gaps=(3,)) + [F("fence_gate_h", 17.7, 13.8)] + fence_run(14.2, 20.8, 20.8, 20.8) + fence_run(14.2, 13.8, 14.2, 20.8) \
        + fence_run(20.8, 13.8, 20.8, 20.8)
    props += [F("water_trough", 15.6, 20.0), F("hay_rack", 19.6, 14.7), F("mud_patch", 17.6, 19.6), F("haybale", 19.8, 19.8)]
    # ---- the cow pasture north of Jory's farm
    props += fence_run(1.4, 33.4, 7.4, 33.4) + fence_run(1.4, 39.2, 7.4, 39.2) + fence_run(1.4, 33.4, 1.4, 39.2) \
        + fence_run(7.4, 33.4, 7.4, 39.2, gaps=(2,)) + [F("fence_gate_v", 7.4, 35.9)]
    props += [F("water_trough", 2.8, 38.4), F("hay_rack", 6.3, 34.3), F("mud_patch", 4.4, 38.2)]
    # ---- the caravan camp at the north road: a fire ring, log seats and a pennant; the wagon comes and goes
    props += [F("campfire", 62.6, 6.9), F("log_seat", 61.4, 7.6), F("log_seat", 63.9, 7.9, 90), F("caravan_pennant", 60.8, 3.6),
              F("mud_patch", 64.4, 7.0), F("tether_post", 67.4, 5.2)]
    # ---- the ceremony stage in the square (south-west quadrant); the market stall moves east of the well
    props += [F("square_stage", 54.5, 34.7), F("podium_board", 54.5, 35.55), F("bench", 52.2, 32.85), F("bench", 56.8, 32.85)]
    # ---- the graveyard: five old stones in the north row, eight plots below (headstones come with the dead)
    for x in (66.4, 68.0, 69.6, 71.2, 72.8):
        props.append(F("gravestone", x, 58.2))
    plots = [(66.8, 59.9), (68.6, 59.9), (70.4, 59.9), (72.2, 59.9), (66.8, 61.5), (68.6, 61.5), (70.4, 61.5), (72.2, 61.5)]
    for x, y in plots:
        props.append(F("grave_plot", x, y + 0.15))
    props += [F("bush", 74.0, 61.6), F("flower_patch_a", 65.6, 61.6)]
    layout["outdoor_props"] = props

    layout["market_stall"] = [65.6, 34.0]
    layout["overhead_props"] = [F("bunting", 54.5, 33.2), F("sign_harbour", 85.0, 50.9)]
    layout["clearings"] = [[4.0, 4.4, 8.4, 6.8], [14.2, 13.8, 6.6, 7.0], [1.4, 33.4, 6.0, 5.8], [60.2, 2.6, 8.2, 6.4],
                           [51.4, 32.0, 6.4, 4.6], [65.0, 57.0, 10.0, 5.6], [13, 9, 5, 4]]
    layout["paddocks"] = [
        dict(id="horse_paddock", kind="horse", rect=[14.2, 13.8, 6.6, 7.0], count=2, sprites=["animal_horse_1", "animal_horse_2"]),
        dict(id="cow_pasture", kind="cow", rect=[1.4, 33.4, 6.0, 5.8], count=3, sprites=["animal_cow_1", "animal_cow_2", "animal_cow_1"]),
    ]
    layout["caravan"] = {"wagon": [64.6, 4.5], "crates": [[66.9, 6.9], [62.0, 3.6]],
                         "interact": dict(kind="caravan", id="caravan", pos=[64.6, 6.2], r=160,
                                          label="The travelling caravan — rare wares from afar")}
    layout["outdoor_interact"] = [
        dict(kind="creatures", id="hale", pos=[10.6, 10.5], r=150, label="The Hales' menagerie — creatures & companions"),
        dict(kind="hall_of_fame", id="square", pos=[54.5, 35.0], r=130, label="The village Hall of Fame — the square's honours board"),
    ]

    spots = layout["outdoor_spots"]
    spots.update({"hale_yard": [10.2, 9.7], "caravan_camp": [63.5, 6.2], "square_podium": [54.5, 34.5],
                  "square_audience_1": [52.2, 31.9], "square_audience_2": [53.4, 32.1], "square_audience_3": [55.6, 32.1],
                  "square_audience_4": [56.8, 31.9], "square_audience_5": [54.5, 31.7], "square_audience_6": [58.2, 33.6],
                  "horse_paddock": [17.4, 13.0], "cow_pasture": [8.4, 36.2]})
    for i, (x, y) in enumerate(plots):
        spots["graveyard_%d" % (i + 1)] = [x, y]

    # ================================================================== street lamps (replace the old lantern posts)
    layout["lamps"] = [[50, 29.2], [68, 32.8], [40, 29.5], [26, 32.6], [12, 29.4], [81.4, 32.6], [57.2, 20], [60.8, 42], [57.4, 52],
                       [33.4, 33.4], [52.0, 14.0], [40.4, 13.4], [24.6, 13.2], [37.2, 10.7], [70.0, 18.4], [79.6, 50.4], [92.2, 51.0],
                       [84.0, 58.6], [64.2, 57.0], [8.6, 24.0], [60.8, 46.0], [83.6, 36.6], [11.0, 33.8], [57.6, 8.0],
                       [72.4, 32.4], [61.0, 8.2], [18.2, 11.2], [30.6, 10.4], [51.0, 33.7], [58.0, 36.4]]
