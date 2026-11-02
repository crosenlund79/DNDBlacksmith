## Soak test (headless): a fresh game left to live for four weeks with light, scripted management.
## godot --headless --path game res://tests/soak.tscn
## Prints the careers, economy and village state at the end so balance can be eyeballed, and fails
## if the simulation throws or the world empties out implausibly.
extends Node


func _ready() -> void:
	Game.new_game()
	var deaths := 0
	for day in 28:
		# light management: Borin mines; any idle hireling goes on a mining trip on Mondays
		if day % 7 == 2:
			for h in Hire.list():
				if h["status"] == "working":
					Hire.send(h["id"], "ironroot_mine")
		Game.advance_minutes(1440)
		# serve whoever waits: sell displayed stock / take repairs at 80% quality
		for c in Shop.waiting().duplicate():
			if c["want"] == "repair":
				Shop.do_repair(c["npc"], 80.0)
		# open returned bags
		for b in Game.state["returns"].duplicate():
			for it in b.get("contents", []):
				Game.add_item(it, false)
		Game.state["returns"].clear()
	var lines := []
	for a in Adv.all().values():
		Adv.ensure(a)
		if a["status"] == "dead":
			deaths += 1
		lines.append("%-16s %-9s lv%d %-8s exp %2d wins %2d gold %4d gear %3d %s" % [a["name"], a["cls"], int(a["level"]), a["status"], int(a["expeditions"]), int(a["victories"]), int(a["gold"]), int(Adv.gear_score(a)), a.get("last_report", "")])
	for h in Hire.list():
		var lv := []
		for s in DB.work_skills:
			lv.append("%s %d" % [s.substr(0, 4), SkillSys.level(h["skills"], s)])
		lines.append("HIRE %-16s %-8s exps %d %s" % [h["name"], h["status"], int(h.get("expeditions", 0)), ", ".join(lv)])
	var sc := []
	for d in DB.destinations:
		sc.append("%s %s" % [d, Regions.knowledge_word(Regions.scouted(d))])
	lines.append("day %d gold %d reputation %.1f (%s) inventory %d orders %d applicants %d" % [Game.day(), Game.gold(), Shop.reputation(), Shop.reputation_word(), Game.inventory().size(), Shop.orders().size(), Game.state["applicants"].size()])
	lines.append("scouting: " + ", ".join(sc))
	lines.append("journal tail: " + " | ".join(Game.state["journal"].slice(-6).map(func(j): return j["text"])))
	print("\n".join(lines))
	var alive := Adv.all().size() - deaths
	print("SOAK %s — %d adventurers alive of %d" % ["OK" if alive >= 3 else "FAIL", alive, Adv.all().size()])
	get_tree().quit(0 if alive >= 3 else 1)
