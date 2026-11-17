## World probe (R2) — a seeded headless campaign that prints a fingerprint of what the world DID, so a build can be
## compared with the one before it ("unchanged where no rule changed; documented differences elsewhere").
##   godot --headless --path game res://tests/world_probe.tscn -- [days] [seed] [steward|idle]
## EN: A new game (journeyman) is played for `days` (default 90) with the global RNG seeded (default 9001). With
##     "steward" (default) the steward runs the workshop at the normal pace; with "idle" the smith does nothing and only
##     the world moves. The fingerprint (JSON, one line, prefixed "PROBE ") lists money, reputation, every adventurer's
##     status/level/deaths/expeditions, finished expeditions by destination and outcome, sponsorships, Lore kinds,
##     customers served, contracts, the day's danger of every site and the shop's prices for a fixed basket. A test-mode
##     save folder is used; real saves are never touched. Not part of the default suite (a 90-day run takes minutes).
## DA: Seedet kampagne-sonde: et fingeraftryk af hvad verden gjorde i 90 dage, til sammenligning mellem to builds.
extends Node


func _ready() -> void:
	Saves.use_test_dir()
	var days := 90
	var rng_seed := 9001
	var mode := "steward"
	var nums := []
	for a in OS.get_cmdline_user_args():
		if str(a) in ["steward", "idle"]:
			mode = str(a)
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
	for d in days:
		for h in 24:
			Game.advance_minutes(60)
			for c in Shop.customers().duplicate():
				if not bool(c.get("present", false)):
					Shop.mark_arrived(str(c["npc"]), false)
	if mode == "steward" and Steward.is_active():
		Steward.deactivate()
	var fp := _fingerprint()
	print("PROBE " + JSON.stringify(fp, "", true))
	Saves.end_test_run()
	get_tree().quit(0)


func _fingerprint() -> Dictionary:
	var advs := {}
	for id in Adv.all().keys():
		var a: Dictionary = Adv.all()[id]
		advs[str(id)] = {"status": str(a.get("status", "")), "level": int(a.get("level", 0)), "gold": int(a.get("gold", 0)),
			"exp": (a.get("history", []) as Array).size()}
	var exps := {}
	for e in Game.state.get("exp", {}).get("done", []) if Game.state.get("exp", {}) is Dictionary else []:
		if e is Dictionary:
			var k := "%s/%s" % [str(e.get("dest", "?")), str(e.get("outcome", e.get("result", "?")))]
			exps[k] = int(exps.get(k, 0)) + 1
	var lore := {}
	for id in Lore.st()["order"]:
		var k := str(Lore.st()["events"][id].get("kind", ""))
		lore[k] = int(lore.get(k, 0)) + 1
	var danger := {}
	for sid in WorldSites.cfg().keys():
		danger[str(sid)] = snappedf(Danger.site(str(sid)), 0.01)
	var prices := {}
	for def in ["sword_iron", "potion_healing", "ingot_iron", "ore_iron"]:
		prices[def] = Items.value(Items.make(def))
	return {"day": Game.day(), "gold": Game.gold(), "rep": snappedf(Shop.reputation(), 0.01),
		"adventurers": advs, "expeditions": exps, "lore": lore, "danger": danger, "item_values": prices,
		"contracts": (Game.state.get("contracts", {}).get("history", []) as Array).size() if Game.state.get("contracts") is Dictionary else 0,
		"ledger_lines": (Game.state.get("ledger", []) as Array).size()}
