## The workshop comes alive — one deterministic end-to-end career for an apprentice, every link checked and carried
## through a reload: hired from the applicants → trained through real work and the smith's mentoring until promoted →
## given a customer's commission → the piece made through the crafting pipeline (real materials, the apprentice's
## craftsmanship and mark) → delivered, i.e. sold to the adventurer → a later deed with it (a unique master slain:
## one Lore event, named / Epic, the Hall of Fame) → the piece comes back and its original maker recognises it, once.
extends SuiteCase

const SMOKE := ["test_apprentice_career"]
const FIN := ["done", "failed", "cancelled"]


func _run_until_done(t: Dictionary, max_min := 6 * 1440) -> void:
	var g := 0
	while not str(t["state"]) in FIN and g < max_min:
		Game.advance_minutes(15)
		g += 15


func _to_hour(h: int) -> void:
	var m := int(Game.state["minute"])
	Game.advance_minutes((h * 60 - m + 1440) % 1440 if (h * 60 - m + 1440) % 1440 != 0 else 1440)


func test_apprentice_career() -> void:
	fresh_game()
	seed(1212)
	train("smithing", 6)
	Game.state["gold"] = 50000
	(Game.state["hirelings"] as Array).clear()   # keep Borin's own work out of the stores under test
	# 1. hire
	check(Apprentices.unlocked(), "1. the smith can take an apprentice (%s)" % Apprentices.unlock_reason())
	var g := 0
	while Apprentices.applicants().is_empty() and g < 20:
		Apprentices.refresh_applicants()
		g += 1
	var fee_gold := Game.gold()
	eq(Apprentices.hire(0), "", "an applicant is hired")
	var a: Dictionary = Apprentices.staff()[-1]
	a["traits"] = []
	var aid := str(a["id"])
	check(Game.gold() < fee_gold, "the signing fee is paid")
	eq(str(a["rank"]), "novice", "they start as a novice")
	# 2. train through real work (smelting) and the smith's daily mentoring until promoted
	var days := 0
	var smelted := 0
	while Apprentices.rank_index(a) < 1 and days < 40:
		_to_hour(8)
		var before := Game.count("ingot_iron")
		check(Apprentices.mentor(aid) == "" or days > 0, "the smith teaches at the start of the day")
		give("ore_iron", 8)
		give("coal", 4)
		var t := Apprentices.add_task("prep", {"recipe": "smelt_iron", "repeat": 4, "assignee": aid})
		if not check(not t.has("error"), "smelting queued (%s)" % t.get("error", "")):
			return
		_run_until_done(t)
		smelted += Game.count("ingot_iron") - before
		days += 1
	check(Apprentices.rank_index(a) >= 1, "2. promoted to %s after %d days of real work (%d works, smithing %d)" % [Apprentices.rank_name(a), days, int(a["works"]), Apprentices.level(a, "smithing")])
	note("promoted to %s after %d days: %d works, smithing %d, %d ingots smelted" % [Apprentices.rank_name(a), days, int(a["works"]), Apprentices.level(a, "smithing"), smelted])
	check(smelted > 0, "the smelting put real ingots in the stores (%d)" % smelted)
	# 3. a customer's commission, made by the apprentice
	var adv := {}
	var ids := Adv.all().keys()
	ids.sort()
	for id in ids:
		var c := Adv.get_a(str(id))
		if str(c["status"]) in ["in_town", "injured"] and not Shop.refuses(str(id)):   # an injured adventurer is in the village too (A2: the seeded path changed)
			adv = c
			break
	if not check(not adv.is_empty(), "a customer in town"):
		return
	var o := {"id": "ord_e2e12", "npc": str(adv["id"]), "slot": "weapon", "stat": "attack", "min": 1, "def": "sword_iron", "tier": 1,
		"reward": 90, "deadline": Game.day() + 6, "status": "open", "note": "", "placed": Game.day(), "priority": "quality"}
	Shop.orders().append(o)
	give("ingot_iron", 2)
	give("leather_cured", 1)
	var ct := Apprentices.add_task("commission", {"order_id": "ord_e2e12", "assignee": aid})
	if not check(not ct.has("error"), "3. the commission goes to the apprentice (%s)" % ct.get("error", "")):
		return
	_to_hour(8)
	_run_until_done(ct)
	eq(str(ct["state"]), "done", "the commission piece is finished")
	var it := Game.find_uid(int(ct["made"][0])) if not (ct["made"] as Array).is_empty() else {}
	if not check(not it.is_empty(), "4. the piece is in the stores"):
		return
	var uid := int(it["uid"])
	eq(str(Provenance.maker(it).get("id", "")), aid, "its maker is the apprentice")
	check(not Provenance.is_mine(it) and Provenance.is_workshop(it), "made at the Ironhand forge, not by the smith himself")
	eq(str(Provenance.mark(it).get("name", "")), str(Apprentices.mark_info(aid).get("name", "?")), "it carries the apprentice's own mark")
	check(float(it["quality"]) < 115.0, "an apprentice's work stays below the smith's exceptional craftsmanship (%.0f%%)" % float(it["quality"]))
	note("commission piece: %s, %.0f%%, %s, mark %s" % [Items.display_name(it), float(it["quality"]), str(it["rarity"]), str(Provenance.mark(it).get("name", ""))])
	eq(str(it.get("for_order", "")), "ord_e2e12", "it waits for the order")
	# 5. delivered: sold to the adventurer
	eq(Shop.fulfil("ord_e2e12", uid), "", "5. the smith delivers the commission")
	var w := Game.find_uid_anywhere(uid)
	eq(Provenance.owner_id(w), str(adv["id"]), "the adventurer owns it now")
	# 6. a later deed: a unique master slain with it
	adv["status"] = "away"
	var e := {"id": "exp_e2e12", "party": [str(adv["id"])], "leader": str(adv["id"]), "dest": "whisperwood", "journal": [], "encounters": [], "start": Game.now()}
	var rec := {"boss": true, "outcome": "win", "enemies": [{"kind": "beast", "name": "the Hollow Alpha", "key": "e0"}],
		"actions": [{"kind": "attack", "target_key": "e0", "hp_after": 0, "actor_id": str(adv["id"]), "weapon_uid": uid, "hit": true}]}
	Expeditions._boss_down(e, {"id": "hollow", "name": "The Hollow"}, rec)
	adv["status"] = "in_town"
	eq(Lore.of_item(uid).filter(func(x): return str(x["kind"]) == "slew").size(), 1, "6. the deed is one Lore event on the piece")
	check(w.has("epic") or ItemStory.is_named(w), "workshop work earns fame (%s)" % Items.display_name(w))
	check(ItemStory.famous_creations().any(func(f): return int(f.get("uid", -1)) == uid), "it hangs among the famous creations")
	note("after the deed: %s (epic %s, named %s)" % [Items.display_name(w), str(w.has("epic")), str(ItemStory.is_named(w))])
	# 7. it comes back; the apprentice who made it recognises it, once
	_to_hour(9)
	a["status"] = "working"
	var mem0 := (a["memories"] as Array).size()
	var card := ItemStory.recognise(w, "repair", str(adv["id"]))
	check(not card.is_empty(), "7. the piece is recognised at the counter")
	check((a["memories"] as Array).size() == mem0 + 1 and str(a["memories"][-1]["text"]).contains("Recognised"), "its maker remembers making it")
	check(ItemStory.recognise(w, "repair", str(adv["id"])).is_empty() and (a["memories"] as Array).size() == mem0 + 1, "only once")
	# 8. everything survives a reload
	var n_ev := Lore.of_item(uid).size()
	if not check(save_load("suite_workshop_e2e"), "8. save and load"):
		return
	var back := Apprentices.get_a(aid)
	w = Game.find_uid_anywhere(uid)
	check(not back.is_empty() and Apprentices.rank_index(back) >= 1, "the apprentice and their rank persist")
	check(not w.is_empty() and str(Provenance.maker(w).get("id", "")) == aid and Lore.of_item(uid).size() == n_ev, "the piece, its maker and its story persist")
	check((back["creations"] as Array).has(uid) or (back["creations"] as Array).has(float(uid)), "the apprentice's creations list it")
	check(ItemStory.recognise(w, "repair", str(adv["id"])).is_empty(), "the reunion is not repeated after loading")


## Midgame economy: two trained apprentices produce ordinary longsword stock for three weeks. Materials are bought at
## their value, wages are paid by the daily simulation, the pieces are valued at the shop's price. The workshop must
## pay its way — and still not out-craft the smith's own exceptional work.
func test_solo_to_workshop_economy() -> void:
	fresh_game()
	seed(2012)
	train("smithing", 6)
	Game.state["gold"] = 5000
	(Game.state["hirelings"] as Array).clear()
	check(Apprentices.max_staff() == 1, "a solo smithy has room for one apprentice")
	Property.dev_grant_unit("cobbler")
	eq(Apprentices.max_staff(), 2, "a second workshop room makes room for two")
	var crew := []
	for i in 2:
		var g := 0
		while Apprentices.applicants().is_empty() and g < 20:
			Apprentices.refresh_applicants()
			g += 1
		if not check(Apprentices.hire(0) == "", "hire apprentice %d" % (i + 1)):
			return
		var a: Dictionary = Apprentices.staff()[-1]
		a["traits"] = []
		a["rank"] = "apprentice"
		a["skills"]["smithing"] = {"lvl": 3, "xp": 0}
		crew.append(a)
	check(Apprentices.hire_reason() != "", "the staff limit holds (%s)" % Apprentices.hire_reason())
	var cost := 0
	var made: Array = []
	var gold0 := Game.gold()
	var wages_before := gold0
	for d in 21:
		_to_hour(7)
		for a in crew:
			var mats := 2 * (2 * int(DB.item("ingot_iron").get("value", 10)) + int(DB.item("leather_cured").get("value", 12)))
			Game.add_gold(-mats, "supplies", "Materials for the apprentices")
			cost += mats
			give("ingot_iron", 4)
			give("leather_cured", 2)
			var t := Apprentices.add_task("craft", {"recipe": "iron_longsword", "repeat": 2, "assignee": str(a["id"])})
			check(not t.has("error"), "day %d: work queued (%s)" % [d, t.get("error", "")])
		Game.advance_minutes(12 * 60)
	for t in Apprentices.tasks():
		for u in t.get("made", []):
			made.append(int(u))
	var value := 0
	var best_q := 0.0
	for u in made:
		var it := Game.find_uid(int(u))
		if not it.is_empty():
			value += Shop.price_of(it)
			best_q = maxf(best_q, float(it["quality"]))
	var wages := wages_before - Game.gold() - cost   # what the daily simulation took besides materials
	note("21 days, 2 apprentices: %d longswords worth %d g; materials %d g, wages and upkeep %d g; best piece %.0f%%" % [made.size(), value, cost, wages, best_q])
	check(made.size() >= 30, "they produce real stock (%d pieces)" % made.size())
	check(wages > 0, "wages were paid (%d g)" % wages)
	check(value > cost + wages, "the workshop pays its way (%d g of goods for %d g)" % [value, cost + wages])
	check(best_q < 115.0, "routine apprentice work never reaches the smith's exceptional craftsmanship (%.0f%%)" % best_q)
	check(not Apprentices.can_make(crew[0], "dragonscale_armor").is_empty(), "the hardest work stays with the smith")
