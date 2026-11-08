## ApprenticeDev — developer shortcuts for the workshop apprentices (iteration 012), used by the F10 dev panel and the
## rendered playtest. Each returns a short message for the panel's status line.
## DA: Udviklergenveje til lærlingene (F10-panelet og den grafiske playtest).
class_name ApprenticeDev
extends RefCounted


static func unlock() -> String:
	if Apprentices.unlocked():
		return "Apprentices are already unlocked."
	var guard := 0
	var need := int((Apprentices.cfg("unlock") as Dictionary).get("smithing", 6))
	while Game.player_level("smithing") < need and guard < 200:
		Game.grant_player_xp("smithing", SkillSys.xp_needed(Game.player_level("smithing") + 1))
		guard += 1
	return "Smithing %d: apprentices unlocked." % Game.player_level("smithing")


static func add_applicant() -> String:
	unlock()
	var before := Apprentices.applicants().size()
	var keep: Array = Apprentices.applicants().duplicate(true)
	Apprentices.refresh_applicants()
	var fresh: Array = Apprentices.st()["applicants"]
	if not fresh.is_empty():
		keep.append(fresh[0])
	Apprentices.st()["applicants"] = keep.slice(maxi(0, keep.size() - 4))
	Events.apprentices_changed.emit()
	return "Applicants on the board: %d (was %d)." % [Apprentices.applicants().size(), before]


static func hire_one() -> String:
	unlock()
	if Apprentices.applicants().is_empty():
		Apprentices.refresh_applicants()
	if not Game.can_afford(int(Apprentices.applicants()[0].get("fee", 0))):
		Game.add_gold(500, "dev", "Developer funds")
	var err := Apprentices.hire(0)
	return err if err != "" else "Hired %s." % str(Apprentices.staff()[-1]["name"])


## Materials for every open crafting/prep/commission task (one more piece's worth of what is missing).
static func give_materials() -> String:
	var n := 0
	for t in Apprentices.open_tasks():
		var e := Apprentices.estimate(t)
		var miss: Dictionary = e.get("missing", {})
		var mats: Dictionary = e.get("materials", {})
		for d in mats:
			var have := Game.count(str(d))
			var need := int(mats[d])
			if have < need:
				Game.add_item(Items.make(str(d), {"qty": need - have}), false)
				n += need - have
		for d in miss:
			if Game.count(str(d)) < int(miss[d]):
				Game.add_item(Items.make(str(d), {"qty": int(miss[d])}), false)
				n += int(miss[d])
	Events.inventory_changed.emit()
	return "Gave %d units of materials for the queue." % n


## Moves the clock to the next shift event: start (8:00), break (12:00), back (13:00) or end (18:00).
static func advance_shift() -> String:
	var h := Game.hour()
	var target := 8
	for x in [8, 12, 13, 18]:
		if h < x:
			target = x
			break
	var m := int(Game.state["minute"]) % 1440
	var mins := (target * 60 - m + 1440) % 1440
	if mins == 0:
		mins = 1440
	Game.advance_minutes(mins)
	return "Clock moved to %s." % Game.time_string()


static func promote(app_id := "") -> String:
	var staff := Apprentices.staff()
	if staff.is_empty():
		return "No apprentices."
	var a: Dictionary = staff[0] if app_id == "" else Apprentices.get_a(app_id)
	var i := Apprentices.rank_index(a)
	if i >= Apprentices.RANKS.size() - 1:
		return "%s is already a master." % a["name"]
	var r := Apprentices.rank_data(Apprentices.RANKS[i + 1])
	a["rank"] = str(r["id"])
	a["works"] = maxi(int(a.get("works", 0)), int(r.get("works", 0)))
	var sk := Apprentices.best_skill(a)
	if Apprentices.level(a, sk) < int(r.get("skill", 0)):
		a["skills"][sk] = {"lvl": int(r.get("skill", 0)), "xp": 0}
	a["wage"] = int(a["wage"]) + int(r.get("raise", 0))
	Events.apprentices_changed.emit()
	return "%s is now a %s." % [a["name"], str(r.get("name", "")).to_lower()]


static func independence() -> String:
	var staff := Apprentices.staff()
	if staff.is_empty():
		return "No apprentices."
	var a: Dictionary = staff[0]
	a["rank"] = "master"
	a["works"] = maxi(int(a.get("works", 0)), 70)
	a["loyalty"] = maxf(float(a.get("loyalty", 0.0)), 80.0)
	for n in Apprentices.st()["notices"]:
		if str(n.get("app", "")) == str(a["id"]):
			return "%s has already asked." % a["name"]
	Apprentices.give_notice(a)
	return "%s asks to open a workshop of their own — talk to them in the smithy." % a["name"]
