## The Living Workshop — C1 proof journey "the collaborative masterpiece" (canonical §13, PROD-004, PROD-026): the
## Emberwarden Longsword (forge → anvil → rune engraving stand → cauldron → grinding wheel → stitching table) made as
## one staged work order. The smith claims and forges the blade and hones the edge himself (his own checks at the
## stations); a runesmith seats the ember rune, an alchemist quenches the edge, a leatherworker wraps the grip — each at
## their own station. One uid from the order's creation to the stores and on to the buyer; the materials taken once;
## the smith is the maker with his mark; the three specialists are recorded (prov.contrib, one Lore event, their
## memories) and gain experience in their own crafts — the smith none in theirs; the game is saved and loaded in the
## middle of the rune stage without anything lost or doubled; the sword is sold afterwards with its provenance intact.
extends SuiteCase

const SMOKE := ["test_emberwarden_chain"]
const FIN := ["done", "failed", "cancelled"]
const EMBER := "emberwarden_longsword"


func _workshop() -> void:
	fresh_game()
	for u in Property.units():
		Property.dev_grant_unit(str(u["id"]))
	SkillTree.unlock_all()
	Property.dev_install_in_owned()
	Game.state["gold"] = 50000
	(Game.state["hirelings"] as Array).clear()


func _at_hour(h: int) -> void:
	var mins: int = (h * 60 - int(Game.state["minute"]) % 1440 + 1440) % 1440
	Game.advance_minutes(mins)


func _counts() -> Dictionary:
	var out := {}
	for d in ["ingot_steel", "runestone_ember", "coating_flame", "thread_ethereal", "sword_emberwarden"]:
		out[d] = Game.count(d)
	return out


func _until(cond: Callable, max_min: int, seen: Dictionary) -> bool:
	var g := 0
	while not cond.call() and g < max_min:
		Game.advance_minutes(5)
		g += 5
		for a in Apprentices.staff():
			var cur := Apprentices.current(a)
			if str(cur.get("phase", "")) == "working" and str(cur.get("station", "")) != "":
				var arr: Array = seen.get(str(a["id"]), [])
				var ty := Property.type_of(str(cur["station"]))
				if not arr.has(ty):
					arr.append(ty)
				seen[str(a["id"])] = arr
	return cond.call()


func _smith_stage(tid: int) -> bool:
	var err := WorkOrders.begin_smith_stage(tid)
	if not check(err == "", "the smith takes up his stage (%s)" % err):
		return false
	var guard := 0
	while Crafting.active() and Crafting.job().has("order") and guard < 12:
		var qs := []
		for i in int(Crafting.current_op().get("checks", 1)):
			qs.append(104.0)
		Crafting.record_step(Crafting.smith_instance(), qs)
		guard += 1
	return check(not Crafting.active(), "his stage is done and the piece handed on")


func test_emberwarden_chain() -> void:
	_workshop()
	train("smithing", 8)
	var rune := Apprentices.dev_take_on("runesmith", 7, "journeyman", "Edda Vell")
	var alch := Apprentices.dev_take_on("alchemist", 7, "journeyman", "Mira Holt")
	var leath := Apprentices.dev_take_on("leatherworker", 7, "journeyman", "Wren Marsh")
	check(not rune.is_empty() and not alch.is_empty() and not leath.is_empty(), "a runesmith, an alchemist and a leatherworker are on the staff")
	give("ingot_steel", 2)
	give("runestone_ember", 1)
	give("coating_flame", 1)
	give("thread_ethereal", 1)
	var c0 := _counts()
	var rc0 := Game.player_level("runecraft")
	var rxp0 := int(Game.player_skills().get("runecraft", {}).get("xp", 0))
	var axp0 := int(Game.player_skills().get("alchemy", {}).get("xp", 0))
	# the order: one uid reserved now, five stages
	var t := Apprentices.add_task("craft", {"recipe": EMBER})
	check(not t.has("error"), "the Emberwarden order is queued (%s)" % t.get("error", ""))
	var tid := int(t["id"])
	var uid := int(t.get("uid", 0))
	check(uid > 0 and Game.find_uid(uid).is_empty(), "uid %d is reserved for the piece, nothing half-built in the stores" % uid)
	eq(WorkOrders.stages(t).size(), 5, "five stages")
	eq(WorkOrders.assign_stage(tid, 0, "player"), "", "the smith claims the forging (forge and anvil)")
	eq(WorkOrders.assign_stage(tid, 3, "player"), "", "…and the honing at the grinding wheel")
	check(WorkOrders.assign_stage(tid, 1, str(alch["id"])) != "", "an alchemist cannot be given the rune stage: %s" % WorkOrders.assign_stage(tid, 1, str(alch["id"])))
	_at_hour(8)
	Game.advance_minutes(5)
	check(str(t["blocker"]).begins_with("Waiting for you"), "the order waits for the smith at the forge: %s" % t["blocker"])
	# 1. the smith forges
	_smith_stage(tid)
	var c1 := _counts()
	eq(c0["ingot_steel"] - c1["ingot_steel"], 2, "the order took its two steel ingots")
	eq(c0["runestone_ember"] - c1["runestone_ember"], 1, "…the ember runestone, the flame coating and the thread, once")
	eq(str(WorkOrders.stages(t)[0]["by"]), "player", "the forging stage is the smith's")
	# 2. the runesmith at the rune engraving stand — saved and loaded in the middle of it
	var seen := {}
	check(_until(func(): return str(t.get("worker", "")) == str(rune["id"]) and float(t.get("progress", 0.0)) > 5.0, 600, seen), "the runesmith is seating the rune")
	check(Property.type_of(str(t.get("station", ""))) == "rune_engraving_stand", "…at a rune engraving stand (%s)" % t.get("station", ""))
	var mid := JSON.stringify({"ops": t["ops_done"], "taken": t["taken"], "uid": t["uid"], "stages": t["stages"]}, "", true)
	check(save_load("suite_lw_ember_mid"), "saved and loaded in the middle of the rune stage")
	t = Apprentices.task(tid)
	eq(JSON.stringify({"ops": t["ops_done"], "taken": t["taken"], "uid": t["uid"], "stages": t["stages"]}, "", true), mid,
		"the order is exactly as it was: stages, worker records, materials in hand, the reserved uid")
	eq(_counts(), c1, "nothing came back to the stores, nothing was doubled")
	eq(str(t.get("worker", "")), str(rune["id"]), "the runesmith is still on it")
	rune = Apprentices.get_a(str(rune["id"]))
	alch = Apprentices.get_a(str(alch["id"]))
	leath = Apprentices.get_a(str(leath["id"]))
	# 3. the alchemist quenches; 4. the order waits for the smith's honing
	check(_until(func(): return WorkOrders.stage_index(t) == 3 and str(t.get("worker", "")) == "", 900, seen), "rune and quench done; the honing waits for the smith")
	eq(str(WorkOrders.stages(t)[1]["by"]), str(rune["id"]), "the runesmith did the rune stage")
	eq(str(WorkOrders.stages(t)[2]["by"]), str(alch["id"]), "the alchemist did the quench")
	_smith_stage(tid)
	# 5. the leatherworker wraps the grip, the order finishes
	check(_until(func(): return str(t["state"]) in FIN, 900, seen), "the leatherworker finishes the grip (%s %s)" % [t["state"], t.get("blocker", "")])
	eq(str(t["state"]), "done", "the order is done")
	check(seen.get(str(rune["id"]), []).has("rune_engraving_stand"), "the runesmith worked at the rune engraving stand %s" % str(seen.get(str(rune["id"]), [])))
	check(seen.get(str(alch["id"]), []).has("cauldron"), "the alchemist at the cauldron %s" % str(seen.get(str(alch["id"]), [])))
	check(seen.get(str(leath["id"]), []).has("stitching_table"), "the leatherworker at the stitching table %s" % str(seen.get(str(leath["id"]), [])))
	# the piece
	var it := Game.find_uid(uid)
	check(not it.is_empty(), "the Emberwarden Longsword is in the stores under the uid reserved at creation")
	eq(str(it.get("def", "")), "sword_emberwarden", "…and it is the Emberwarden")
	var mk := Provenance.maker(it)
	eq(str(mk.get("id", "")), Provenance.SMITH_ID, "the smith is the maker")
	eq(str(mk.get("mark", "")), Provenance.SMITH_MARK, "…with the Ironhand mark")
	var con := Provenance.contributors(it)
	eq(con.map(func(e): return str(e["profession"])), ["runesmith", "alchemist", "leatherworker"], "three specialists recorded on the piece")
	eq(con.map(func(e): return str(e["who"])), [str(rune["id"]), str(alch["id"]), str(leath["id"])], "…by name")
	check(con.all(func(e): return float(e["quality"]) > 0.0 and str(e["at"]) != ""), "each with their quality and the station they worked at")
	var ops: Array = it.get("craft", {}).get("ops", [])
	eq(ops.map(func(o): return str(o.get("by", ""))), ["player", "player", str(rune["id"]), str(alch["id"]), "player", str(leath["id"])], "every operation records its hand")
	var ev := Lore.of_item(uid).filter(func(e): return str(e.get("kind", "")) == "contributed")
	eq(ev.size(), 1, "one Lore event names the contributors")
	check(str(ev[0]["text"]).contains("Edda Vell") and str(ev[0]["text"]).contains("Brannoc"), "…and the maker: %s" % str(ev[0]["text"]))
	check((rune["memories"] as Array).any(func(m): return str(m.get("text", "")).contains("Emberwarden")), "the runesmith remembers her stage")
	var c2 := _counts()
	eq(c2["sword_emberwarden"] - c0["sword_emberwarden"], 1, "exactly one sword")
	eq(c2["ingot_steel"], c1["ingot_steel"], "no material taken twice")
	eq(Game.player_level("runecraft"), rc0, "the smith's runecraft is unchanged")
	eq(int(Game.player_skills().get("runecraft", {}).get("xp", 0)), rxp0, "…he gains nothing from the runesmith's stage")
	eq(int(Game.player_skills().get("alchemy", {}).get("xp", 0)), axp0, "…nor from the alchemist's")
	var sc := ItemRegistry.scan()
	check((sc["dup"] as Array).is_empty() and (sc["shared"] as Array).is_empty() and (sc["stray"] as Array).is_empty(), "identity clean: %s" % ItemRegistry.scan_text(sc))
	# sold afterwards: the same sword, its maker and contributors travel with it
	it["for_sale"] = true
	var sold := ""
	for aid in Adv.all():
		var a: Dictionary = Adv.all()[aid]
		a["gold"] = 9000
		it["price"] = 1
		if Shop.sell_to(str(aid), uid) == "":
			sold = str(aid)
			break
	check(sold != "", "an adventurer buys the Emberwarden")
	var held := Game.find_uid_anywhere(uid)
	if check(not held.is_empty(), "it is found by its uid in the buyer's hands"):
		eq(str(held.get("owner", "")), sold, "…owned by the buyer")
		eq(str(Provenance.maker(held).get("id", "")), Provenance.SMITH_ID, "the maker is still the smith")
		eq(Provenance.contributors(held).size(), 3, "the three contributors are still recorded")
		check(is_same(held, it), "one creation, one object: the same sword")
