## The Living Workshop — seeded acceptance soak (headless; NOT part of the default suite: a 365-day run takes minutes).
##   godot --headless --path game res://tests/lw_soak.tscn -- [poor|est|both] [days]      (default: both 365)
## EN: Steward Mode runs the workshop for `days` days (measured again at day 30) in two seeded games:
##     (i)  "poor" — a poor early game exactly as S2's soak (seed 5151, the starting gold and materials, no employees,
##          field hirelings let go, the default instructions), to compare with S2's 365-day figure;
##     (ii) "est"  — an established five-hand workshop (the smith at Smithing 8; a blacksmith, a runesmith, an alchemist
##          and a leatherworker; several anvils, forges, wheels and a second cauldron and stitching table bought through
##          Property; four staged Emberwarden orders whose forging and honing the smith claimed; the spouse minding
##          the counter with a 10 % cap; a starting purse of 3,000 g).
##     Asserts conservation — the purse's change equals the sum of the ledger lines (counted hour by hour, the ledger
##     itself keeps only 400) and the steward's report reconciles; the material record balances (before + in − used ±
##     not itemised = remaining) with nothing "not itemised" during the run; every uid unique (ItemRegistry.scan,
##     Uniques.audit); every piece made is made once and is still somewhere or its leaving is in Lore; zero player
##     experience — and prints the measurements: gold trajectory and income by category, pieces and work orders made,
##     stages per profession, station-instance use, help requests, the spouse's sales and discount, real seconds per
##     simulated day, save-file size at day 30 and at the end. Exit code 0 = every invariant held.
## DA: Seedet soak-test af Steward Mode i 30/365 dage: bevarelse af guld og materialer, unikke uid'er, nul XP; målinger.
extends Node

var fails: Array[String] = []
var made: Array = []         # every piece built while recording: {uid, def, day, maker, stages: [[profession, by]…], hands}
var made_count := {}         # uid → times built (must be 1)
var recording := false


func _ready() -> void:
	Events.item_crafted.connect(_on_crafted)
	var which := "both"
	var days := 365
	for a in OS.get_cmdline_user_args():
		if str(a) in ["poor", "est", "both"]:
			which = str(a)
		elif str(a).is_valid_int():
			days = int(a)
	var out := []
	if which in ["poor", "both"]:
		out.append(_run("poor", days))
	if which in ["est", "both"]:
		out.append(_run("est", days))
	print("\n".join(PackedStringArray(out)))
	if fails.is_empty():
		print("LW SOAK OK — every invariant held")
	else:
		print("LW SOAK FAILED — %d invariant(s) broken:" % fails.size())
		for f in fails.slice(0, 40):
			print("  ✗ " + f)
	Saves.end_test_run()
	get_tree().quit(0 if fails.is_empty() else 1)


func _check(cond: bool, what: String) -> bool:
	if not cond:
		fails.append(what)
	return cond


# ------------------------------------------------------------------ what is made
func _on_crafted(it: Dictionary) -> void:
	if not recording or not it.has("uid"):
		return
	var uid := int(it["uid"])
	made_count[uid] = int(made_count.get(uid, 0)) + 1
	var rid := str(it.get("craft", {}).get("recipe", ""))
	var ops: Array = it.get("craft", {}).get("ops", [])
	var stages := []
	var hands := {}
	for s in WorkOrders.plan(rid):
		var i0 := int((s["ops"] as Array)[0])
		var by := str(ops[i0].get("by", "player")) if i0 < ops.size() else "player"
		if by == "":
			by = "player"
		var prof := "smith" if by == "player" else Workers.profession(by)
		if prof == "":
			prof = "unknown"
		stages.append([prof, by])
		hands[by] = true
	made.append({"uid": uid, "def": str(it.get("def", "")), "day": Game.day(), "rid": rid, "stages": stages, "hands": hands.size(),
		"equipment": Items.is_equipment(it), "maker": str(it.get("craft", {}).get("maker", "player"))})


# ------------------------------------------------------------------ set-ups
func _poor() -> void:
	seed(5151)
	Game.new_game("journeyman")
	(Game.state["hirelings"] as Array).clear()


func _buy_instance(t: String) -> void:
	var before := Property.instances(t, false)
	var err := Property.buy_station(t)
	if not _check(err == "", "set-up: another %s (%s)" % [t, err]):
		return
	var iid := ""
	for x in Property.instances(t, false):
		if not before.has(x):
			iid = str(x)
	var plan := Property.plan_copy()
	var why := Property.auto_place(plan, iid)
	_check(why == "" and Property.commit(plan) == "", "set-up: %s placed (%s)" % [iid, why])


func _give(def: String, n: int) -> void:
	if bool(DB.item(def).get("stack", false)):
		Game.add_item(Items.make(def, {"qty": n}), false)
	else:
		for i in n:
			Game.add_item(Items.make(def, {"quality": 80.0}), false)


func _established() -> void:
	seed(9001)
	Game.new_game("journeyman")
	(Game.state["hirelings"] as Array).clear()
	Game.state["gold"] = 60000   # the purse that bought the rooms and stations (fixture)
	var guard := 0
	var more := true
	while more and guard < 12:
		more = false
		for u in Property.units():
			if not Property.owns(str(u["id"])) and Property.buy_unit(str(u["id"])) == "":
				more = true
		guard += 1
	SkillTree.unlock_all()
	Property.dev_install_in_owned()
	while Game.player_level("smithing") < 8:
		Game.grant_player_xp("smithing", SkillSys.xp_needed(Game.player_level("smithing") + 1))
	for p in ["blacksmith", "runesmith", "alchemist", "leatherworker"]:
		_check(not Apprentices.dev_take_on(p, 6, "journeyman").is_empty(), "set-up: a %s taken on" % p)
	for t in ["anvil", "anvil", "forge", "forge", "grinding_wheel", "cauldron", "stitching_table"]:
		_buy_instance(t)
	for pair in [["ingot_iron", 30], ["ingot_steel", 12], ["coal", 30], ["leather_cured", 16], ["thread_linen", 8], ["thread_ethereal", 4],
			["runestone_ember", 4], ["coating_flame", 4], ["runestone_blank", 4], ["herb_emberleaf", 8], ["herb_moonwort", 8], ["reagent_salt", 8]]:
		_give(str(pair[0]), int(pair[1]))
	var t := Apprentices.add_task("craft", {"recipe": "emberwarden_longsword", "repeat": 4})
	if _check(not t.has("error"), "set-up: four Emberwardens ordered (%s)" % t.get("error", "")):
		WorkOrders.assign_stage(int(t["id"]), 0, "player")
		WorkOrders.assign_stage(int(t["id"]), 3, "player")
	Steward.st()["orders"]["order_rules"]["max_difficulty"] = 6   # the player's rule lets his smith forge them
	Social.set_romance("roisin", "married")
	Social.ensure("roisin")["aff"] = 80.0
	Roisin.st()["free"] = true
	_check(bool(Family.ask("roisin")["ok"]), "set-up: Róisín minds the counter")
	Family.set_discount_cap(10)
	Game.state["gold"] = 3000   # the established workshop's working purse (fixture)


# ------------------------------------------------------------------ the run
func _seat() -> void:
	for c in Shop.customers().duplicate():
		if not bool(c.get("present", false)):
			Shop.mark_arrived(str(c["npc"]), false)


func _mat_x() -> Dictionary:
	var out := {}
	for d in MaterialLedger.st().get("m", {}):
		out[str(d)] = int(MaterialLedger.st()["m"][d].get("x", 0))
	return out


func _forge_equipment() -> Dictionary:
	var out := {}
	for it in Game.inventory():
		if Items.is_equipment(it):
			out[int(it["uid"])] = true
	return out


func _save_size(label: String, day: int) -> int:
	var slot := "lw_soak_%s_d%d" % [label, day]
	if not _check(Saves.save(slot), "%s: saved at day %d (%s)" % [label, day, Saves.last_error]):
		return -1
	var f := FileAccess.open(Saves.path(slot), FileAccess.READ)
	var n := int(f.get_length()) if f != null else -1
	if f != null:
		f.close()
	Saves.delete(slot)
	return n


func _run(label: String, days: int) -> String:
	made.clear()
	made_count.clear()
	if label == "poor":
		_poor()
	else:
		_established()
	var lines := PackedStringArray()
	var gold0 := Game.gold()
	var skills0 := JSON.stringify(Game.player_skills())
	var nodes0 := JSON.stringify(SkillTree._st()["nodes"])
	var x0 := _mat_x()
	var fam0 := {"n": int(Family.st().get("sales_n", 0)) if Game.state.has("family") else 0, "gold": int(Family.st().get("sales_gold", 0)) if Game.state.has("family") else 0,
		"off": int(Family.st().get("discount_gold", 0)) if Game.state.has("family") else 0}
	if not _check(Steward.activate() == "", "%s: the steward takes over (%s)" % [label, Steward.can_activate()]):
		return ""
	recording = true
	var lg: Array = Game.state["ledger"]
	var mark: Dictionary = lg[lg.size() - 1] if not lg.is_empty() else {}
	var lsum := 0
	var lcount := 0
	var by_cat := {}
	var busy := {}
	var help_ids := {}
	var counter := {"duty_h": 0, "browse": 0, "goods": 0, "display": 0}
	var peak := {}
	var waits_free := 0
	var gold_by_month := [gold0]
	var forge_prev := _forge_equipment()
	var vanished := []
	var t0 := Time.get_ticks_msec()
	var t30 := 0
	var size30 := -1
	var checkpoint30 := ""
	for d in days:
		for h in 24:
			for q in 4:
				Game.advance_minutes(15)
				var used_by_type := {}
				for sid in Property.st()["stations"]:
					if Apprentices.instance_user(str(sid)) != "":
						busy[str(sid)] = int(busy.get(str(sid), 0)) + 15
						used_by_type[Property.type_of(str(sid))] = int(used_by_type.get(Property.type_of(str(sid)), 0)) + 1
				for ty in used_by_type:
					peak[ty] = maxi(int(peak.get(ty, 0)), int(used_by_type[ty]))
				# nobody waits for a station while another of its kind stands free
				for t2 in Apprentices.open_tasks():
					if not str(t2.get("blocker", "")).begins_with("Waiting for the"):
						continue
					var ops := Crafting.operations(str(t2.get("recipe", "")))
					if ops.is_empty():
						continue
					var ty2 := Property.type_of(str(ops[mini(int(t2.get("op", 0)), ops.size() - 1)].get("station", "")))
					for sid2 in Property.instances(ty2):
						if Apprentices.instance_user(str(sid2)) == "":
							waits_free += 1
							break
			_seat()
			# the ledger lines written this hour (the ledger keeps its last 400 only)
			var i := lg.size() - 1
			var fresh := []
			while i >= 0 and not (not mark.is_empty() and is_same(lg[i], mark)):
				fresh.push_front(lg[i])
				i -= 1
			if not mark.is_empty() and i < 0:
				_check(false, "%s: the ledger mark was lost on day %d (more than 400 lines an hour?)" % [label, Game.day()])
			for ln in fresh:
				lsum += int(ln["amount"])
				lcount += 1
				by_cat[str(ln["cat"])] = int(by_cat.get(str(ln["cat"]), 0)) + int(ln["amount"])
			if not lg.is_empty():
				mark = lg[lg.size() - 1]
			for hr in WorkOrders.help():
				help_ids[int(hr.get("id", -1))] = true
			# the counter as the spouse finds it: her hours on duty, browsing customers, sellable pieces on display
			if Game.state.has("family") and Family.helps():
				if Family.on_duty():
					counter["duty_h"] = int(counter["duty_h"]) + 1
					counter["browse"] = int(counter["browse"]) + Shop.waiting().filter(func(c): return str(c.get("want", "")) == "browse").size()
					counter["goods"] = int(counter["goods"]) + Shop.waiting().filter(func(c): return str(c.get("want", "")) == "goods").size()
					counter["display"] = int(counter["display"]) + Shop.stock().filter(func(x): return Items.is_equipment(x) and str(x.get("for_order", "")) == "" \
						and Steward.protection_reason(x) == "").size()
				else:
					counter["off:" + Family.duty_reason().left(28)] = int(counter.get("off:" + Family.duty_reason().left(28), 0)) + 1
		# pieces that left the forge's stores today: still somewhere, or their leaving is in Lore
		var forge_now := _forge_equipment()
		for u in forge_prev:
			if forge_now.has(u):
				continue
			if not ItemRegistry.find(int(u)).is_empty():
				continue
			var evs := Lore.of_item(int(u)).filter(func(e): return int(e.get("day", 0)) >= Game.day() - 1)
			if evs.is_empty():
				vanished.append(int(u))
		forge_prev = forge_now
		if (d + 1) % 30 == 0:
			gold_by_month.append(Game.gold())
		if d + 1 == 30:
			t30 = Time.get_ticks_msec() - t0
			size30 = _save_size(label, 30)
			checkpoint30 = "%s day 30: gold %d → %d (ledger %+d over %d lines); pieces made %d; %.0f ms per day; save %d bytes" % [label, gold0, Game.gold(),
				lsum, lcount, made.size(), float(t30) / 30.0, size30]
	var ms := Time.get_ticks_msec() - t0
	var skills_end := JSON.stringify(Game.player_skills())
	var r := Steward.deactivate()
	recording = false
	var size_end := _save_size(label, days)
	# ---- invariants
	_check(Game.gold() - gold0 == lsum, "%s: the purse changed by %d, the ledger lines sum to %d" % [label, Game.gold() - gold0, lsum])
	_check(bool(r["gold"]["reconciled"]), "%s: the steward's report reconciles (unexplained %d)" % [label, int(r["gold"]["unexplained"])])
	_check(skills_end == skills0, "%s: zero player experience under the steward" % label)
	_check(JSON.stringify(Game.player_skills()) == skills0, "%s: …and after the hand-back" % label)
	_check(JSON.stringify(SkillTree._st()["nodes"]) == nodes0, "%s: no tree node learned by the steward" % label)
	var bad_rows := []
	var x_moved := {}
	for row in MaterialLedger.rows():
		if int(row["before"]) + int(row["acquired"]) - int(row["used"]) + int(row["unitemised"]) != int(row["remaining"]):
			bad_rows.append(str(row["def"]))
	var x1 := _mat_x()
	for dd in x1:
		if int(x1[dd]) != int(x0.get(dd, 0)):
			x_moved[dd] = int(x1[dd]) - int(x0.get(dd, 0))
	_check(bad_rows.is_empty(), "%s: the material record balances for every material %s" % [label, str(bad_rows)])
	_check(x_moved.is_empty(), "%s: no material moved without a record during the run %s" % [label, str(x_moved)])
	var sc := ItemRegistry.scan()
	_check((sc["dup"] as Array).is_empty() and (sc["shared"] as Array).is_empty() and (sc["stray"] as Array).is_empty(), "%s: uids unique (%s)" % [label, ItemRegistry.scan_text(sc)])
	_check(Uniques.audit().is_empty(), "%s: Uniques.audit clean" % label)
	var twice := made_count.keys().filter(func(u): return int(made_count[u]) > 1)
	_check(twice.is_empty(), "%s: every piece built once %s" % [label, str(twice.slice(0, 5))])
	var lost := []
	for m in made:
		if bool(m["equipment"]) and ItemRegistry.find(int(m["uid"])).is_empty() and Lore.of_item(int(m["uid"])).is_empty():
			lost.append("%s %d" % [m["def"], int(m["uid"])])
	_check(lost.is_empty(), "%s: every piece made is still somewhere or its leaving is recorded %s" % [label, str(lost.slice(0, 5))])
	_check(vanished.is_empty(), "%s: nothing left the forge's stores unrecorded %s" % [label, str(vanished.slice(0, 5))])
	_check(waits_free == 0, "%s: nobody waited for a station while another of its kind stood free (%d quarter-hours)" % [label, waits_free])
	_check(Saves.save("lw_soak_rt") and Saves.load_slot("lw_soak_rt"), "%s: save and load after the run" % label)
	Saves.delete("lw_soak_rt")
	var sc2 := ItemRegistry.scan()
	_check((sc2["dup"] as Array).is_empty() and (sc2["stray"] as Array).is_empty(), "%s: identity clean after loading" % label)
	# ---- measurements
	var cats := PackedStringArray()
	var ck: Array = by_cat.keys()
	ck.sort_custom(func(a, b): return absi(int(by_cat[a])) > absi(int(by_cat[b])))
	for c in ck:
		cats.append("%s %+d" % [c, int(by_cat[c])])
	var prof := {}
	var staged := 0
	var orders_by_hands := 0
	var kinds := {}
	for m in made:
		for s in m["stages"]:
			prof[str(s[0])] = int(prof.get(str(s[0]), 0)) + 1
		if (m["stages"] as Array).size() > 1:
			staged += 1
			if int(m["hands"]) > 1:
				orders_by_hands += 1
		var k := "equipment" if bool(m["equipment"]) else "materials/goods"
		kinds[k] = int(kinds.get(k, 0)) + 1
	var util := PackedStringArray()
	var sk: Array = busy.keys()
	sk.sort()
	for sid in sk:
		util.append("%s %d h (%.1f%% of 07–19)" % [sid, int(busy[sid]) / 60, 100.0 * float(busy[sid]) / float(days * 720)])
	var multi := PackedStringArray()
	for sid2 in sk:
		if Property.instance_count(Property.type_of(str(sid2))) > 1:
			multi.append("%s %d h" % [sid2, int(busy[sid2]) / 60])
	var sm: Dictionary = r.get("smith", {})
	var fam := {"n": 0, "gold": 0, "off": 0}
	if Game.state.has("family"):
		fam = {"n": int(Family.st().get("sales_n", 0)) - int(fam0["n"]), "gold": int(Family.st().get("sales_gold", 0)) - int(fam0["gold"]),
			"off": int(Family.st().get("discount_gold", 0)) - int(fam0["off"])}
	lines.append("==== %s: %d days under the steward (seed %s) ====" % [label, days, "5151" if label == "poor" else "9001"])
	if checkpoint30 != "":
		lines.append(checkpoint30)
	lines.append("%s gold %d → %d (change %+d; income %d, expenses %d); ledger %d lines summing to %+d; report reconciled %s" % [label, gold0, Game.gold(),
		Game.gold() - gold0, int(r["gold"]["income"]), int(r["gold"]["expenses"]), lcount, lsum, str(r["gold"]["reconciled"])])
	lines.append("%s gold every 30 days: %s" % [label, str(gold_by_month)])
	lines.append("%s income/expense by category: %s" % [label, ", ".join(cats)])
	lines.append("%s made: %d pieces/batches (%s); staged work orders finished %d (by several hands %d); smith: %d pieces, %d repairs (+%d g)"
		% [label, made.size(), str(kinds), staged, orders_by_hands, int(sm.get("made_count", 0)), int(sm.get("repairs_count", 0)), int(sm.get("repair_gold", 0))])
	lines.append("%s stages per profession: %s" % [label, str(prof)])
	lines.append("%s orders: taken on %d, delivered %d, declined %d; staff works %s" % [label, int(r["orders"]["counts"]["accepted"]), int(r["orders"]["counts"]["delivered"]),
		int(r["orders"]["counts"]["declined"]), str((r["staff"]["current"] as Array).map(func(s): return "%s %s +%d" % [str(s["name"]).split(" ")[0], s["rank"], int(s["works"])]))])
	lines.append("%s station use (hours in use; share of the 12 working hours a day): %s" % [label, ", ".join(util)])
	if not multi.is_empty():
		lines.append("%s instances of a multiplied type (hours in use): %s; most instances of a type in use at once: %s" % [label, ", ".join(multi), str(peak)])
	lines.append("%s help requests: %d; spouse at the counter: %d sales, %d g, %d g discount given; counter hours %s"
		% [label, help_ids.size(), int(fam["n"]), int(fam["gold"]), int(fam["off"]), str(counter)])
	lines.append("%s staff who left: %s; matters deferred to the smith now: %d" % [label, str(r["staff"]["left"]), (r.get("deferred", []) as Array).size()])
	lines.append("%s steward: %d decisions %s; xp withheld %d; sales %d (%d g)" % [label, int(r["decisions"]["total"]), str(r["decisions"]["by_kind"]), int(sm.get("xp_withheld", 0)),
		int(r["sales"]["count"]), int(r["sales"]["gold"])])
	lines.append("%s time: %.1f s real for %d days = %.0f ms per simulated day; save file %d bytes at day 30, %d bytes at day %d"
		% [label, ms / 1000.0, days, float(ms) / float(days), size30, size_end, days])
	lines.append("%s materials not itemised during the run: %s; identity %s" % [label, str(x_moved), ItemRegistry.scan_text(sc)])
	return "\n".join(lines)
