## Long-campaign probe (R3 "One History", TECH-026 / LORE-008) — how history, saves and the simulation hold up over
## years of play.
##   godot --headless --path game res://tests/long_probe.tscn -- [days] [seed] [steward|idle]
## EN: A seeded new game (journeyman) runs for `days` (default 1095 = three years) — with the steward working the forge
##     (default) or with the smith idle. Every 90 days it prints one "LONG {json}" line: Lore events, digests and folded
##     ids, Chronicle entries, the save's size and the time to save and load it, and the simulation's cost per day over the
##     last 90 days. At the end it audits history: every id held by an item, a tombstone or a person resolves; every
##     Chronicle line is a Lore event; no uid is held twice. A test-mode save folder is used; real saves are never touched.
##     Not part of the default suite. Exit code 1 if an audit fails.
## DA: Langtidssonde: Lore-vækst, gemmestørrelse, indlæsningstid og simulationstid pr. dag over flere år.
extends Node


func _ready() -> void:
	Saves.use_test_dir()
	var days := 1095
	var rng_seed := 9001
	var mode := "steward"
	var keep := false   # copy the last save out of the test folder (to user://long_probe_keep.json) for analysis
	var nums := []
	for a in OS.get_cmdline_user_args():
		if str(a) in ["steward", "idle"]:
			mode = str(a)
		elif str(a) == "keep":
			keep = true
		elif str(a).is_valid_int():
			nums.append(int(a))
	if nums.size() > 0:
		days = nums[0]
	if nums.size() > 1:
		rng_seed = nums[1]
	seed(rng_seed)
	Game.new_game("journeyman")
	if mode == "steward":
		Steward.activate()
	var t0 := Time.get_ticks_msec()
	var worst_day := 0
	for d in days:
		var td := Time.get_ticks_msec()
		for h in 24:
			Game.advance_minutes(60)
			for c in Shop.customers().duplicate():
				if not bool(c.get("present", false)):
					Shop.mark_arrived(str(c["npc"]), false)
		worst_day = maxi(worst_day, Time.get_ticks_msec() - td)
		if (d + 1) % 90 == 0 or d + 1 == days:
			var sim_ms := Time.get_ticks_msec() - t0
			print("LONG " + JSON.stringify(_measure(d + 1, sim_ms, worst_day, mode)))
			t0 = Time.get_ticks_msec()
			worst_day = 0
	if mode == "steward" and Steward.is_active():
		Steward.deactivate()
	if keep:
		DirAccess.copy_absolute(Saves.path("long_probe"), ProjectSettings.globalize_path("user://long_probe_keep.json"))
	var bad := _audit()
	print("AUDIT " + JSON.stringify(bad))
	Saves.end_test_run()
	get_tree().quit(0 if (bad["dangling"] == 0 and bad["feed_not_lore"] == 0 and bad["duplicate_uids"] == 0) else 1)


func _measure(day: int, sim_ms: int, worst_day: int, mode: String) -> Dictionary:
	var s := Lore.st()
	var digests := 0
	for e in s["events"].values():
		if str(e.get("kind", "")) == "digest":
			digests += 1
	var steward_on := Steward.is_active()
	if steward_on:
		Steward.deactivate()
	var ts := Time.get_ticks_msec()
	var ok := Saves.save("long_probe")
	var save_ms := Time.get_ticks_msec() - ts
	var size := FileAccess.get_file_as_bytes(Saves.path("long_probe")).size()
	var tl := Time.get_ticks_msec()
	var ok2 := Saves.load_slot("long_probe")
	var load_ms := Time.get_ticks_msec() - tl
	if steward_on:
		Steward.activate()
	var days_in := 90 if day % 90 == 0 else day % 90
	return {"day": day, "mode": mode, "lore_events": (s["events"] as Dictionary).size(), "digests": digests,
		"folded_ids": (s["folded"] as Dictionary).size(), "chronicle": (s["chron_ids"] as Array).size(),
		"save_kb": size / 1024, "save_ms": save_ms, "load_ms": load_ms, "saved": ok and ok2,
		"ms_per_day": int(float(sim_ms) / maxf(1.0, days_in)), "worst_day_ms": worst_day,
		"items": ItemRegistry.all_physical(ItemRegistry.ALL, true).size(), "adventurers": Adv.all().size(),
		"gold": Game.gold()}


func _audit() -> Dictionary:
	var dangling := 0
	for it in ItemRegistry.all_physical(ItemRegistry.ALL, true):
		for id in Provenance.st(it).get("events", []):
			if Lore.event(str(id)).is_empty():
				dangling += 1
	for tb in ItemRegistry.tombstones().values():
		for id in tb.get("events", []):
			if Lore.event(str(id)).is_empty():
				dangling += 1
	for a in Adv.all().values():
		for id in a.get("lore", []):
			if Lore.event(str(id)).is_empty():
				dangling += 1
	var feed_not_lore := 0
	for c in Chronicle.entries():
		if Lore.event(str(c.get("event", ""))).is_empty():
			feed_not_lore += 1
	var seen := {}
	var dup := 0
	for it in ItemRegistry.all_physical(ItemRegistry.ALL, false):
		var u := int(it.get("uid", -1))
		if u <= 0:
			continue
		if seen.has(u):
			dup += 1
		seen[u] = true
	var causal := 0
	for e in Lore.st()["events"].values():
		if e.has("because"):
			causal += 1
	return {"dangling": dangling, "feed_not_lore": feed_not_lore, "duplicate_uids": dup, "causal_links": causal,
		"tombstones": ItemRegistry.tombstones().size(), "uniques_audit": Uniques.audit().size()}
