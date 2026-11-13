## The Living Workshop — FAMILY (#50–52, #40): the smith's spouse at the shop counter (opt-in by her own character,
## one identity, no employee slot), sales through the shop's own sale path at the display price less at most the
## discount the player allows (0 % and a positive cap; enforced in the sale path), honest ledger lines and conserved
## money; her hours and schedule; nothing protected, no commissions, repairs only with competence; the steward counting
## her counter work; the smith's pet; the optional 5× night pace under the steward (only while he sleeps, back to the
## day pace on waking, 1× on exit/load/new game, zero XP, the same simulation minute by minute); old saves unchanged.
## (Marriage is set up directly — these tests are about the counter, not the romance.)
extends SuiteCase

const SMOKE := ["test_opt_in_by_character_one_identity", "test_sale_at_display_price_cap_zero", "test_discount_cap_enforced_in_sale_path",
	"test_sleep_pace_follows_sleep_only_in_steward_mode"]


# ------------------------------------------------------------------ fixtures
func _game(rng := 9001) -> void:
	fresh_game("journeyman", rng)
	(Game.state["hirelings"] as Array).clear()
	Shop.customers().clear()
	for it in Game.inventory():
		it.erase("for_sale")   # only the pieces a test puts on display


func _marry(npc := "roisin", aff := 60.0) -> void:
	Social.set_romance(npc, "married")
	Social.ensure(npc)["aff"] = aff
	if npc == Roisin.ID:
		Roisin.st()["free"] = true


func _at(h: int, m := 0) -> void:
	Game.state["minute"] = h * 60 + m


## The sale tests start with her already behind the counter: her stretch of duty began Family.COUNTER_WALK minutes ago
## (pilot 004: the simulation, not a rendered figure, decides when she has walked over; test_counter_walk checks the walk).
func _walked_over() -> void:
	Family.st()["duty_since"] = Game.now() - Family.COUNTER_WALK


## A buyer in town (not the spouse), browsing.
func _buyer(skip := "") -> Dictionary:
	for id in ["sigrun", "kestra", "elowen", "mira"]:
		if id == skip or id == Social.spouse():
			continue
		var a := Adv.get_a(id)
		if a.is_empty():
			continue
		Expeditions.ensure(a)
		a["status"] = "in_town"
		return a
	for a in Adv.all().values():
		if str(a["id"]) != Social.spouse() and str(a["id"]) != skip:
			a["status"] = "in_town"
			return a
	return {}


## A piece on display (at its default list price) that `a` would want.
func _piece_for(a: Dictionary) -> Dictionary:
	var keep := int(a["gold"])
	a["gold"] = 1000000
	var found := {}
	for def in DB.items:
		if str(DB.item(str(def)).get("type", "")) == "companion":
			continue
		var it := Items.make(str(def), {"quality": 97.0})
		if it.is_empty() or Items.slot(it) == "":
			continue
		if Adv.purchase_check(a, it, Shop.list_price(it)) == "":
			found = it
			break
	a["gold"] = keep
	if found.is_empty():
		return {}
	Game.add_item(found, false)
	Shop.set_for_sale(int(found["uid"]), true)
	return found


func _seat(npc: String, want := "browse", extra := {}) -> Dictionary:
	var now := Game.day() * 24 + Game.hour()
	var c := {"npc": npc, "want": want, "arrived": now, "seated": now, "seat": Shop.free_seat(), "present": true, "budget": 0, "looking_for": ""}
	c.merge(extra, true)
	Shop.customers().append(c)
	return c


func _last_ledger() -> Dictionary:
	var lg: Array = Game.state["ledger"]
	return lg[lg.size() - 1] if not lg.is_empty() else {}


func _helping(npc := "roisin", aff := 60.0) -> void:
	_marry(npc, aff)
	var r := Family.ask(npc)
	check(bool(r["ok"]), "%s agrees to help (%s)" % [npc, str(r["text"]).left(60)])


# ------------------------------------------------------------------ opt-in, identity, competence
func test_opt_in_by_character_one_identity() -> void:
	_game()
	eq(Family.talk_options("roisin").size(), 0, "no counter talk before marriage")
	check(not Game.state.has("family"), "reading the family state does not create it (old saves load unchanged)")
	_marry("roisin", 10.0)
	var opts := Family.talk_options("roisin")
	eq(str(opts[0]["id"]), "f_counter_ask", "married: she can be asked")
	check(Roisin.options("garden").any(func(o): return str(o["id"]) == "f_counter_ask"), "Róisín's own conversation offers it")
	var no := Family.ask("roisin")
	check(not bool(no["ok"]) and not Family.helps(), "too cool between you: she declines (%s)" % str(no["text"]).left(50))
	check(Family.talk_options("roisin")[0].has("disabled"), "her answer stands for the day")
	Game.advance_minutes(1440)
	Social.ensure("roisin")["aff"] = 40.0
	var staff_before := Apprentices.staff().size()
	var yes: Dictionary = Talk.choose("roisin", "f_counter_ask", "garden")
	check(Family.helps() and Family.helper() == "roisin", "warm enough: she agrees (%s)" % str(yes.get("text", "")).left(50))
	eq(Apprentices.staff().size(), staff_before, "no apprentice record, no employee slot")
	eq(Workers.kind("roisin"), "spouse", "her own NPC id is her worker identity")
	eq(Workers.kind("spouse"), "spouse", "… also as 'spouse'")
	eq(str(Workers.resolve("spouse:roisin")["id"]), "roisin", "one identity, whatever the alias")
	check(not Workers.workshop_actors().has("roisin"), "not a workshop craft worker (no station work planned for her)")
	eq(str(Workers.profile("roisin")["family"]), "family", "her profile: family, read-only")
	check(Workers.can_do("roisin", "dagger") != "", "craft work follows her actual competence: none (%s)" % Workers.can_do("roisin", "dagger"))
	check(Family.repair_reason() != "", "no repairs without competence (%s)" % Family.repair_reason())
	eq(Workers.growth_cap("roisin", "smithing"), Workers.BASIC_LEVEL, "she is no specialist")
	# Mira would rather die out there than behind a counter — unless devoted
	_game()
	_marry("mira", 60.0)
	check(not bool(Family.ask("mira")["ok"]), "Mira declines at a warm 60")
	Game.advance_minutes(1440)
	Social.ensure("mira")["aff"] = 90.0
	check(bool(Family.ask("mira")["ok"]), "… and agrees when devoted")
	eq(Family.WILLING["roisin"] < Family.WILLING["mira"], true, "willingness differs by character")
	# kept across save/load; released on request; she leaves the counter if things cool far enough
	check(save_load("lw_family_optin"), "save/load")
	check(Family.helps() and Family.helper() == "mira", "she still helps after loading")
	Talk.choose("mira", "f_counter_release", "village")
	check(not Family.helps(), "released when asked")
	Social.ensure("mira")["aff"] = 90.0
	Game.advance_minutes(1440)
	Family.ask("mira")
	Social.ensure("mira")["aff"] = 50.0
	Family.tick()
	check(not Family.helps(), "she stops by herself when things between you cool far enough")


# ------------------------------------------------------------------ the counter
func test_sale_at_display_price_cap_zero() -> void:
	_game()
	_helping("roisin")
	eq(Family.discount_cap(), 0, "the default cap is 0 % (your display prices stand)")
	var a := _buyer()
	var it := _piece_for(a)
	if not check(not it.is_empty(), "a piece the buyer wants is on display"):
		return
	var listed := Shop.price_of(it)
	a["gold"] = listed + 5
	_seat(str(a["id"]))
	_at(10)
	check(Family.on_duty(), "on duty at 10:00")
	eq(Family.spot("roisin"), "smithy_counter_back", "behind the shop counter")
	var gold0 := Game.gold()
	var purse0 := int(a["gold"])
	_walked_over()
	Family.tick()
	var mine := Game.find_uid(int(it["uid"]))
	check(mine.is_empty(), "the piece left the stores")
	eq(str(a["equipment"].get(Items.slot(it), {}).get("uid", -1)), str(it["uid"]), "the buyer wears the very same piece (one uid)")
	eq(Game.gold() - gold0, listed, "the forge's purse gained the display price")
	eq(purse0 - int(a["gold"]), listed, "the buyer paid it from their own purse (money conserved)")
	var ln := _last_ledger()
	eq(str(ln.get("cat", "")), "sales", "a normal sales ledger line")
	eq(str(ln.get("party", "")), str(a["id"]), "naming the buyer as the party")
	check(str(ln.get("note", "")).contains("Róisín at the counter"), "the note says who sold it (%s)" % str(ln.get("note", "")))
	check(Shop.customer(str(a["id"])).is_empty(), "the customer was served and left")
	eq(int(Family.status()["today"]["n"]), 1, "today's sales: 1")
	# at 0 % a buyer short of the display price is not served
	var b := _buyer(str(a["id"]))
	var it2 := _piece_for(b)
	if it2.is_empty():
		skip("no second piece for a second buyer")
		return
	var listed2 := Shop.price_of(it2)
	b["gold"] = listed2 - 3
	_seat(str(b["id"]))
	_at(11)
	Family.tick()
	check(not Game.find_uid(int(it2["uid"])).is_empty(), "cap 0 %: no sale below the display price")
	check(Shop.sell_to(str(b["id"]), int(it2["uid"]), listed2 - 3, "roisin") != "", "the sale path refuses any discount at 0 %")


func test_discount_cap_enforced_in_sale_path() -> void:
	_game()
	_helping("roisin")
	eq(Family.set_discount_cap(10), "", "the player allows her 10 %")
	check(Family.set_discount_cap(30) != "" and Family.set_discount_cap(7.5) != "", "the cap is a whole percent from 0 to 25")
	eq(Family.discount_cap(), 10, "still 10 %")
	var a := _buyer()
	var it := _piece_for(a)
	if not check(not it.is_empty(), "a piece on display"):
		return
	var listed := Shop.price_of(it)
	var floor_p := Family.floor_price(listed)
	check(floor_p >= int(ceil(listed * 0.9)) and floor_p < listed, "the floor is at most 10 %% off (%d of %d)" % [floor_p, listed])
	_at(10)
	# the sale path itself
	check(Shop.sell_to(str(a["id"]), int(it["uid"]), listed + 1, "roisin") != "", "never above the display price")
	check(Shop.sell_to(str(a["id"]), int(it["uid"]), floor_p - 1, "roisin") != "", "never below the cap")
	check(Shop.sell_to(str(a["id"]), int(it["uid"]), floor_p, "") != "", "nobody else may give a discount")
	_at(12, 30)
	check(Shop.counter_price_reason(listed, floor_p, "roisin") != "", "not while she is off duty (midday)")
	_at(20)
	check(Shop.counter_price_reason(listed, floor_p, "roisin") != "", "not after hours")
	_at(10)
	eq(Shop.counter_price_reason(listed, floor_p, "roisin"), "", "within the cap, on duty: allowed")
	# she gives only as much off as the buyer needs
	var short := listed - int(listed * 0.05)
	a["gold"] = short
	_seat(str(a["id"]))
	var gold0 := Game.gold()
	_walked_over()
	Family.tick()
	check(Game.find_uid(int(it["uid"])).is_empty(), "sold with a discount within the cap")
	eq(Game.gold() - gold0, short, "for exactly what the buyer could pay (≥ the floor)")
	eq(int(a["gold"]), 0, "taken from the buyer's purse")
	var ln := _last_ledger()
	check(str(ln.get("note", "")).contains("% off"), "the ledger line says the discount (%s)" % str(ln.get("note", "")))
	eq(int(Family.status()["today"]["off"]), listed - short, "the discount given is recorded")
	# a buyer who would need more than the cap is not served
	var b := _buyer(str(a["id"]))
	var it2 := _piece_for(b)
	if it2.is_empty():
		skip("no second piece")
		return
	var l2 := Shop.price_of(it2)
	b["gold"] = int(l2 * 0.8)
	_seat(str(b["id"]))
	_at(11)
	Family.tick()
	check(not Game.find_uid(int(it2["uid"])).is_empty(), "20 % short with a 10 % cap: no sale")


func test_goods_within_budget_and_cap() -> void:
	_game()
	_helping("roisin")
	Family.set_discount_cap(15)
	var pot := Items.make("potion_healing", {"qty": 3})
	Game.add_item(pot, false)
	var stack: Dictionary = {}
	for it in Game.inventory():
		if str(it["def"]) == "potion_healing":
			stack = it
	Shop.set_for_sale(int(stack["uid"]), true)
	var unit := Shop.price_of(stack) / maxi(1, int(stack.get("qty", 1)))
	var budget := unit - maxi(1, int(unit * 0.1))
	_seat("martha", "goods", {"looking_for": "potion_healing", "budget": budget})
	_at(10)
	var gold0 := Game.gold()
	var n0 := Game.count("potion_healing")
	_walked_over()
	Family.tick()
	eq(Game.count("potion_healing"), n0 - 1, "one draught sold")
	eq(Game.gold() - gold0, budget, "at the villager's budget, within 15 %")
	eq(str(_last_ledger().get("party", "")), "martha", "the ledger names the villager's household")
	_seat("tobin", "goods", {"looking_for": "potion_healing", "budget": int(unit * 0.5)})
	Family.tick()
	eq(Game.count("potion_healing"), n0 - 1, "half price is beyond her cap: no sale")


func test_hours_schedule_and_what_she_leaves_to_the_smith() -> void:
	_game()
	_helping("sigrun", 70.0)
	var sg := Adv.get_a("sigrun")
	sg["status"] = "in_town"
	for h in [9, 11, 13, 17]:
		_at(h)
		check(Family.on_duty(), "on duty at %02d:00" % h)
	for h in [8, 12, 18, 21]:
		_at(h)
		check(not Family.on_duty() and Family.spot("sigrun") == "", "off duty at %02d:00 (%s)" % [h, Family.duty_reason()])
	_at(10)
	sg["status"] = "away"
	check(not Family.on_duty() and Family.duty_reason().contains("road"), "on the road she is not at the counter (%s)" % Family.duty_reason())
	sg["status"] = "injured"
	check(not Family.on_duty(), "hurt: resting, not at the counter")
	sg["status"] = "in_town"
	_seat("sigrun", "repair")
	check(not Family.on_duty(), "waiting at the counter herself: a customer, not on duty")
	Shop.remove_customer("sigrun")
	# protected/Epic pieces, repairs and commissions wait for the smith
	var a := _buyer("sigrun")
	var it := _piece_for(a)
	if not check(not it.is_empty(), "a piece on display"):
		return
	Steward.protect(int(it["uid"]), true)
	a["gold"] = Shop.price_of(it) * 2
	_seat(str(a["id"]))
	Family.tick()
	check(not Game.find_uid(int(it["uid"])).is_empty(), "a protected piece is not hers to sell")
	Steward.protect(int(it["uid"]), false)
	Shop.remove_customer(str(a["id"]))
	_seat("martha", "repair", {"item": Items.make("dagger", {"quality": 60.0}), "pay": 10})
	_seat(str(a["id"]), "multi", {"parts": []})
	var g0 := Game.gold()
	Family.tick()
	check(Shop.customer("martha").size() > 0 and Game.gold() == g0, "a repair waits for the smith (no competence)")
	check(Shop.customer(str(a["id"])).size() > 0, "a commission waits for the smith")
	# widowed: the arrangement ends with her
	Social.set_romance("sigrun", "widowed")
	Family.tick()
	check(not Family.helps() and str(Game.state["family"]["helper"]) == "", "no spouse, no helper")


func test_through_the_clock_and_the_steward_counts_her_work() -> void:
	_game()
	_helping("roisin")
	var a := _buyer()
	var it := _piece_for(a)
	if not check(not it.is_empty(), "a piece on display"):
		return
	Steward.protect(int(it["uid"]), false)
	a["gold"] = Shop.price_of(it) + 1
	var xp0 := JSON.stringify(Game.player_skills())
	_at(9, 20)
	eq(Steward.activate(), "", "the steward takes over")
	Steward.set_orders({"duties": {"sales": false}})   # her counter, not the steward's own sales duty
	_seat(str(a["id"]))
	Game.advance_minutes(25)   # 09:45 — her duty began at the 09:30 round: still walking over
	check(not Game.find_uid(int(it["uid"])).is_empty(), "nothing sold while she walks over (09:45)")
	Game.advance_minutes(15)   # 10:00 — her tick runs with the clock (Game.advance_minutes)
	check(Game.find_uid(int(it["uid"])).is_empty(), "she sold it at the 10:00 tick, once she had walked over")
	var sold: Array = Steward.st()["acc"]["sold"]
	check(not sold.is_empty() and str(sold[-1].get("by", "")) != "", "the steward's report counts her sale (%s)" % str(sold))
	var r := Steward.deactivate()
	eq(int(r.get("sales", {}).get("count", 0)), 1, "While You Were Away: one sale")
	eq(JSON.stringify(Game.player_skills()), xp0, "zero player experience")


# ------------------------------------------------------------------ the pet
func test_pet_is_the_smiths_own_creature() -> void:
	_game()
	check(Family.pet().is_empty(), "no creature, no pet")
	Game.state["gold"] = 5000
	var stock := Commerce.creature_stock()
	var bought := 0
	for i in stock.size():
		if bought < 2 and not bool(stock[i].get("sold", false)) and Commerce.buy_creature(i) == "":
			bought += 1
	if bought == 0:
		skip("no creature in the yard this week")
		return
	var pets := Family.pets()
	eq(pets.size(), bought, "the creatures in the stores")
	var first := int(Family.pet()["uid"])
	check(Companions.is_companion(Family.pet()), "the pet is a creature from Hale Farm")
	Shop.set_for_sale(first, true)
	check(int(Family.pet().get("uid", -1)) != first, "a creature on display is merchandise, not the pet")
	Shop.set_for_sale(first, false)
	eq(int(Family.pet()["uid"]), first, "the one kept longest walks with him")
	if pets.size() > 1:
		var other := int(pets[1]["uid"]) if int(pets[1]["uid"]) != first else int(pets[0]["uid"])
		eq(Family.set_pet(other), "", "he may choose another")
		eq(int(Family.pet()["uid"]), other, "… which then walks with him")
	var a := {}
	for x in Adv.all().values():
		if Companions.of(x).is_empty() and str(x["id"]) != Social.spouse():
			x["status"] = "in_town"
			a = x
			break
	var given := int(Family.pet()["uid"])
	eq(Commerce.give_owned_creature(given, str(a.get("id", ""))), "", "given to an adventurer")
	eq(int(Companions.of(a).get("uid", -1)), given, "it is theirs now")
	check(int(Family.pet().get("uid", -1)) != given, "an adventurer's companion is never his pet")


# ------------------------------------------------------------------ the night pace (#40)
func _to_sleep() -> void:
	var g := 0
	while not StewardSmith.asleep() and g < 400:
		Game.advance_minutes(5)
		g += 1


func test_sleep_pace_follows_sleep_only_in_steward_mode() -> void:
	_game()
	check(not Steward.sleep_pace_on(), "the night pace is off by default")
	eq(Steward.set_orders({"sleep_pace": true}), "", "the player may choose it")
	check(Steward.set_orders({"sleep_pace": 5}) != "", "on or off only")
	_at(21, 30)
	eq(Engine.time_scale, 1.0, "outside Steward Mode nothing changes")
	var xp0 := JSON.stringify(Game.player_skills())
	eq(Steward.activate(), "", "the steward takes over")
	eq(Engine.time_scale, 1.5, "awake: the steward's pace")
	_to_sleep()
	check(StewardSmith.asleep(), "the smith went to bed (%s)" % Game.time_string())
	eq(Engine.time_scale, Steward.SLEEP_PACE, "asleep: the whole simulation at 5×")
	eq(Game.speed, 1, "the clock alone is not sped up on top of it")
	eq(Steward.set_orders({"sleep_pace": false}), "", "turned off while he sleeps")
	eq(Engine.time_scale, 1.5, "… back to the day pace at once")
	Steward.set_orders({"sleep_pace": true})
	eq(Engine.time_scale, Steward.SLEEP_PACE, "… and on again")
	eq(Steward.set_orders({"pace": 1.0}), "", "normal day pace chosen")
	eq(Engine.time_scale, Steward.SLEEP_PACE, "the night pace still applies while he sleeps")
	var g := 0
	while StewardSmith.asleep() and g < 200:
		Game.advance_minutes(5)
		g += 1
	check(Game.hour() == 6 and Game.state["minute"] % 60 <= 5, "he woke at 6:00 (%s)" % Game.time_string())
	eq(Engine.time_scale, 1.0, "awake: back to the chosen day pace at once")
	Steward.set_orders({"pace": 1.5})
	eq(Engine.time_scale, 1.5, "1.5× by day")
	_to_sleep()
	eq(Engine.time_scale, Steward.SLEEP_PACE, "the next night: 5×")
	Steward.deactivate()
	eq(Engine.time_scale, 1.0, "taking the workshop back: normal speed at once")
	eq(JSON.stringify(Game.player_skills()), xp0, "zero player experience through the nights")
	# a save made at 5× loads at normal speed; a new game too
	eq(Steward.activate(), "", "again")
	_to_sleep()
	eq(Engine.time_scale, Steward.SLEEP_PACE, "asleep: 5×")
	check(Saves.save("lw_family_night"), "saved while he sleeps")
	check(Saves.load_slot("lw_family_night"), "loaded")
	Saves.delete("lw_family_night")
	check(not Steward.is_active() and Engine.time_scale == 1.0, "a loaded save runs at normal speed with the mode off")
	eq(Steward.activate(), "", "once more")
	_to_sleep()
	fresh_game()
	eq(Engine.time_scale, 1.0, "a new game starts at normal pace")


## The pace only maps real seconds to game minutes: the simulation itself advances minute by minute through
## Game.advance_minutes either way — two seeded runs, night pace on and off, end in exactly the same state.
func test_sleep_pace_same_simulation_minute_by_minute() -> void:
	var sig := []
	for night in [false, true]:
		_game(4242)
		Steward.set_orders({"sleep_pace": night})
		_at(18)
		eq(Steward.activate(), "", "steward on (night pace %s)" % str(night))
		var hours := [0]
		var on_hour := func(_d, _h): hours[0] += 1
		Events.hour_passed.connect(on_hour)
		for i in 30 * 12:
			Game.advance_minutes(5)
		Events.hour_passed.disconnect(on_hour)
		eq(hours[0], 30, "30 hourly ticks in 30 hours (night pace %s)" % str(night))
		var lines := PackedStringArray()
		for e in Steward.st()["log"]:
			if str(e["kind"]) != "pace":
				lines.append("%d %s %s %s" % [int(e["day"]), str(e["time"]), str(e["kind"]), str(e["text"])])
		sig.append("%d|%d|%d|%s|%s" % [Game.day(), int(Game.state["minute"]), Game.gold(), JSON.stringify(Game.state["ledger"]), "\n".join(lines)])
		Steward.deactivate()
	eq(sig[0] == sig[1], true, "the same days, ledger and steward decisions with and without the night pace")


## A villager's walk covers its whole step each frame, past waypoints: the same game minutes at any pace or frame
## rate (before, the rest of a step was lost at each waypoint — at 5× a walk took ~20 % more game minutes, measured
## in the rendered phase).
func test_npc_walk_same_game_minutes_at_any_step() -> void:
	_game()
	var res := {}
	for frames in [40, 4]:   # the same game time in small steps (1×, 60 fps) or big ones (a faster pace / a slow frame)
		var n := NPCActor.new()
		n.setup("mira", "chars/mira", "Mira")
		n.speed = 80.0
		n.position = Vector2.ZERO
		var pts := PackedVector2Array()
		for i in range(1, 31):
			pts.append(Vector2(10.0 * i, 0.0))   # 30 waypoints, 10 px apart (300 px)
		n.go(pts)
		var total := 2.5   # seconds of (scaled) frame time: 200 px at 80 px/s
		for f in frames:
			n._process(total / float(frames))
		res[frames] = n.position.x
		n.free()
	check(absf(float(res[40]) - 200.0) < 0.5, "small steps walk 200 px (%.1f)" % float(res[40]))
	check(absf(float(res[4]) - 200.0) < 0.5, "big steps walk the same 200 px (%.1f)" % float(res[4]))


# ------------------------------------------------------------------ pilot 004: one decision, with or without a world
## Her walk to the counter is simulation time: COUNTER_WALK minutes from the round her duty begins (09:00, again after
## the midday hour), through the real clock; off duty and released she is not there.
func test_counter_walk_by_simulation_time() -> void:
	_game()
	_helping("roisin")
	_at(8, 50)
	Game.advance_minutes(10)   # the 09:00 round: her duty begins, she sets off
	check(Family.on_duty() and not Family.at_counter(), "09:00: on duty, on her way")
	Game.advance_minutes(15)
	check(not Family.at_counter(), "09:15: still on her way")
	Game.advance_minutes(15)
	check(Family.at_counter(), "09:30: behind the counter (%d minutes' walk)" % Family.COUNTER_WALK)
	Game.advance_minutes(150)   # 12:00: the midday hour
	check(not Family.on_duty() and not Family.at_counter(), "12:00: the midday hour, not at the counter")
	Game.advance_minutes(60)    # 13:00: back on duty, walking over again
	check(Family.on_duty() and not Family.at_counter(), "13:00: on duty again, on her way back")
	Game.advance_minutes(30)
	check(Family.at_counter(), "13:30: behind the counter again")
	Family.release()
	check(not Family.at_counter(), "released: not at the counter")


## A stand-in for the rendered world (group "world") with her figure hidden, far from the counter and still walking —
## what the old check read. The decision and every sale must be the same as in a headless game.
func _stand_in_world() -> Node2D:
	var scr := GDScript.new()
	scr.source_code = "extends Node2D\nvar npcs := {}\nvar spots := {}\n"
	scr.reload()
	var w: Node2D = scr.new()
	var fig := Node2D.new()
	fig.position = Vector2(4000, 4000)
	fig.visible = false
	fig.set_meta("walking", true)
	w.add_child(fig)
	w.set("npcs", {"roisin": fig})
	w.set("spots", {Family.COUNTER_SPOT: Vector2.ZERO})
	w.add_to_group("world")
	var root := (Engine.get_main_loop() as SceneTree).root
	root.get_child(root.get_child_count() - 1).add_child(w)   # the suite's own node (the root is busy setting up)
	check(Engine.get_main_loop().get_first_node_in_group("world") == w, "the stand-in world is in the scene tree")
	return w


func _morning(with_world: bool) -> Array:
	_game(4242)
	_helping("roisin")
	var a := _buyer()
	var it := _piece_for(a)
	if it.is_empty():
		return ["no piece"]
	a["gold"] = Shop.price_of(it) + 5
	_at(8, 45)
	_seat(str(a["id"]))
	var w: Node2D = _stand_in_world() if with_world else null
	var out := []
	for i in 6:   # 08:45 → 10:15, round by round
		Game.advance_minutes(15)
		out.append("%s at_counter=%s sold=%s gold=%d" % [Game.time_string(), Family.at_counter(),
			Game.find_uid(int(it["uid"])).is_empty(), Game.gold()])
	if w != null:
		w.get_parent().remove_child(w)
		w.free()
	out.append(JSON.stringify((Game.state["ledger"] as Array).slice(-3)))
	return out


func test_same_decisions_with_or_without_a_world() -> void:
	var headless := _morning(false)
	var with_world := _morning(true)
	note("headless: " + " | ".join(headless.slice(0, 6)))
	eq(with_world, headless, "the same rounds, the same sale, the same ledger with a rendered world as without one")
	check(headless.any(func(l): return str(l).contains("sold=true")), "she did sell that morning (once she had walked over)")
	check(str(headless[0]).contains("at_counter=false") and str(headless[1]).contains("at_counter=false"),
		"not at the counter at 09:00 and 09:15 (walking over)")
