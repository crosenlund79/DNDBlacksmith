## Contracts — major commissions from patrons, worked in blocks of hours at the Project Bench (The Living Realm, 5).
## EN: A patron (a wealthy merchant, the village muster, the Highmarsh Watch, the Merchants' Guild, a Warden of the
##     Marches — and in time the Royal Household) sends a sealed letter: a large order of pieces made from known
##     recipes ("40 iron shortswords and 20 round shields"), a minimum craftsmanship, the hours it takes, a deadline,
##     an advance and a payment on delivery, the reputation at stake, the ordinary materials the patron sends along
##     (a sealed crate beside the bench, used before anything from the stores), rare materials the smith must find
##     himself (Guide shows the routes) and sometimes one individually crafted masterpiece he forges at the stations
##     as usual and lays into the order. Offers come from real accomplishments (standing(): reputation, contracts
##     delivered well, Hall of Fame plaques, Epic pieces, renown) and each letter says why it came.
##     Large orders are not crafted piece by piece: the smith works BLOCKS of hours at the bench (time passes, fatigue
##     rises, quality and pace follow his skill and freshness); qualified apprentices work hours through the existing
##     Apprentices queue (task kind "contract"). Each unit takes its materials when it is begun. On delivery the
##     outcome (excellent / good / poor, on time or late) sets the pay, the reputation and the patron's favour, and is
##     remembered (Lore, Chronicle, Hall of Fame for the finest). A patron whose deadline is long past withdraws the
##     order — never a game over. State: Game.state["contracts"] (created lazily — old saves load unchanged).
## DA: Store kontrakter fra mæcener, arbejdet i blokke af timer ved projektbænken; tilbud kommer af virkelige
##     bedrifter, lærlinge hjælper via opgavekøen, og udfaldet giver betaling, omdømme og gunst.
##
## Public API (static):
##   st() -> Dictionary                         offers() / active() / history() -> Array        get_c(id) -> Dictionary
##   standing() -> Dictionary {rep, good, good_by_tier, plaques, epics, renown, crafted, tier, reasons{tier: [..]}}
##   patron(pid) / patron_name(pid) / favour(pid) -> int        tier_open(tier) -> String ("" = open, else what is missing)
##   make_offer(tpl_id, why := "") -> Dictionary  (tests/dev; the daily letter goes through on_day)
##   accept(id) -> String   decline(id) -> String   abandon(id) -> String
##   work(id, hours) -> Dictionary {hours, units, quality, error}      can_work(id) -> String ("" = yes)
##   next_unit_problem(c) -> String       apprentice_hour(id, app, q) -> float      task_problem(id) -> String
##   work_station(id, worker := "") -> String      stations(id) -> Array          main_recipe(id) -> String
##   masterpiece_candidates(id) -> Array    lay_in_masterpiece(id, uid) -> String
##   ready(id) -> bool   deliver(id) -> Dictionary {outcome, pay, rep, late_days, error}
##   quality(c) -> float   progress(c) -> float   units_text(c) -> String   materials_needed(c) -> Dictionary
##   bench_installed() -> bool    prompt() -> Dictionary (WorldPrompts at the bench)    on_day()
class_name Contracts
extends RefCounted

const BENCH := "project_bench"
const FINISHED := ["delivered", "failed", "declined", "expired"]
const OUTCOME_WORD := {"excellent": "Excellent", "good": "Good", "poor": "Poor", "failed": "Withdrawn"}

## True while the smith works a block at the bench (apprentices then use the contract's other stations).
static var smith_working := false


# ======================================================================= data & state
static func data() -> Dictionary:
	var d: Variant = DB.extra("contracts")
	return d if d is Dictionary else {}


static func cfg(key: String, fallback: Variant = null) -> Variant:
	return (data().get("config", {}) as Dictionary).get(key, fallback)


static func _f(key: String, fallback: float) -> float:
	var v: Variant = cfg(key, fallback)
	return float(v) if (v is int or v is float) else fallback


static func template(tid: String) -> Dictionary:
	for t in data().get("templates", []):
		if str(t.get("id", "")) == tid:
			return t
	return {}


static func patron(pid: String) -> Dictionary:
	return (data().get("patrons", {}) as Dictionary).get(pid, {})


static func patron_name(pid: String) -> String:
	var p := patron(pid)
	return ("%s, %s" % [p.get("name", pid), p.get("title", "")]).trim_suffix(", ")


static func _fresh() -> Dictionary:
	return {"offers": [], "active": [], "history": [], "patrons": {}, "next": 1, "last_offer_day": 0, "notes": []}


static func st() -> Dictionary:
	if Game.state.is_empty():
		return _fresh()
	if not Game.state.has("contracts"):
		Game.state["contracts"] = _fresh()
	var s: Dictionary = Game.state["contracts"]
	var f := _fresh()
	for k in f:
		if not s.has(k):
			s[k] = f[k]
	return s


static func offers() -> Array:
	return st()["offers"]


static func active() -> Array:
	return st()["active"]


static func history() -> Array:
	return st()["history"]


static func get_c(id: String) -> Dictionary:
	for arr in [active(), offers(), history()]:
		for c in arr:
			if str(c.get("id", "")) == id:
				return c
	return {}


static func _pst(pid: String) -> Dictionary:
	var ps: Dictionary = st()["patrons"]
	if not ps.has(pid):
		ps[pid] = {"favour": 0, "done": 0, "good": 0, "last_day": -99}
	return ps[pid]


static func favour(pid: String) -> int:
	return int(_pst(pid).get("favour", 0))


static func _changed() -> void:
	Events.orders_changed.emit()


static func bench_installed() -> bool:
	return Property.is_installed(BENCH)


# ======================================================================= standing: what the smith has earned
## The accomplishments patrons look at. tier = the highest patron tier open now; reasons[tier] = why it is open.
static func standing() -> Dictionary:
	var out := {"rep": Shop.reputation(), "good": 0, "good_by_tier": {}, "plaques": 0, "epics": 0, "renown": false,
		"crafted": int(Game.state.get("stats", {}).get("crafted", 0)), "tier": 0, "reasons": {}, "missing": {}}
	for h in history():
		if str(h.get("outcome", "")) in ["excellent", "good"]:
			out["good"] = int(out["good"]) + 1
			var t := str(int(patron(str(h.get("patron", ""))).get("tier", 1)))
			out["good_by_tier"][t] = int(out["good_by_tier"].get(t, 0)) + 1
	var hof: Array = Game.state.get("hall_of_fame", [])
	out["plaques"] = hof.size()
	out["epics"] = hof.filter(func(e): return str(e.get("kind", "")) == "epic").size()
	out["renown"] = bool(Smithy.renown().get("ok", false))
	for tier in [1, 2, 3, 4]:
		var why := _tier_check(tier, out)
		if str(why["missing"]) == "":
			out["tier"] = tier
			out["reasons"][str(tier)] = why["reasons"]
		else:
			out["missing"][str(tier)] = why["missing"]
	return out


static func _rep_phrase() -> String:
	var w := Shop.reputation_word()
	return str({"a modest name": "modest regard", "well respected": "good regard", "renowned": "high renown", "poorly thought of": "low regard"}.get(w, "regard"))


## "" when patrons of this tier would write, otherwise what is still missing (shown in the contract view).
static func tier_open(tier: int) -> String:
	var s := standing()
	return "" if int(s["tier"]) >= tier else str(s["missing"].get(str(tier), "earlier tiers first"))


static func _tier_check(tier: int, s: Dictionary) -> Dictionary:
	var rep := float(s["rep"])
	var good := int(s["good"])
	var gbt: Dictionary = s["good_by_tier"]
	var reasons := []
	var miss := []
	match tier:
		1:
			# a working smith with a decent name: pieces forged and a village that does not speak ill of him
			if int(s["crafted"]) >= 8 and rep > -8.0:
				reasons.append("%d pieces have left your anvil" % int(s["crafted"]))
				reasons.append("the village holds you in %s" % _rep_phrase())
			elif rep >= 10.0:
				reasons.append("the village holds you in %s" % _rep_phrase())
			else:
				miss.append("forge more pieces (%d of 8) with a decent name in the village" % int(s["crafted"]))
		2:
			if good >= 1:
				reasons.append("you delivered %d major order%s well" % [good, "" if good == 1 else "s"])
			else:
				miss.append("deliver a merchant's or the muster's order well")
			if rep >= 10.0:
				reasons.append("your name is %s" % Shop.reputation_word())
			elif int(s["plaques"]) >= 1:
				reasons.append("your work hangs in the Hall of Fame")
			else:
				miss.append("a respected name (reputation %d of 10) or a Hall of Fame plaque" % int(rep))
		3:
			if int(gbt.get("2", 0)) + int(gbt.get("3", 0)) + int(gbt.get("4", 0)) >= 1 and good >= 2:
				reasons.append("the Watch or the Guild was well served by you")
			else:
				miss.append("deliver an order for the Watch or the Guild well (and two orders in all)")
			if int(s["epics"]) >= 1 or int(s["plaques"]) >= 2:
				reasons.append("%s" % ("an Epic piece of yours is talked about" if int(s["epics"]) >= 1 else "%d of your works hang in the Hall of Fame" % int(s["plaques"])))
			else:
				miss.append("an Epic piece or two Hall of Fame plaques")
			if rep < 15.0:
				miss.append("reputation 15 (now %d)" % int(rep))
		4:
			if int(gbt.get("3", 0)) + int(gbt.get("4", 0)) >= 1 and good >= 3:
				reasons.append("a Warden of the Marches praised your armour")
			else:
				miss.append("serve a great lord well (and three major orders in all)")
			if int(s["epics"]) >= 1 or int(s["plaques"]) >= 4:
				reasons.append("%s" % ("an Epic piece of yours is famous" if int(s["epics"]) >= 1 else "%d plaques in the Hall of Fame" % int(s["plaques"])))
			else:
				miss.append("an Epic piece or four Hall of Fame plaques")
			if bool(s["renown"]):
				reasons.append("the forge is renowned")
			else:
				miss.append("a renowned forge")
	return {"reasons": reasons, "missing": "; ".join(PackedStringArray(miss))}


# ======================================================================= offers
static func _hpu(rid: String) -> float:
	return snappedf(0.6 + 0.4 * float(Crafting.difficulty(rid)), 0.25)


## Builds a contract from a template (not yet offered). `why`: the accomplishments the letter names.
static func _build(tpl: Dictionary, why: String) -> Dictionary:
	var s := st()
	var id := "ct_%d" % int(s["next"])
	s["next"] = int(s["next"]) + 1
	var lines := []
	var hours := 0.0
	var units := 0
	for l in tpl.get("lines", []):
		var rid := str(l["recipe"])
		var n := int(l["n"])
		var h := _hpu(rid)
		lines.append({"recipe": rid, "def": str(DB.recipe(rid).get("output", "")), "n": n, "hpu": h})
		hours += h * n
		units += n
	var pid := str(tpl.get("patron", ""))
	var fav := favour(pid)
	var pay := int(round(float(tpl.get("pay", 0)) * (1.0 + 0.05 * clampi(fav, -4, 6))))
	var c := {"id": id, "tpl": str(tpl["id"]), "patron": pid, "title": str(tpl.get("title", "")), "text": str(tpl.get("text", "")),
		"why": why, "lines": lines, "units_total": units, "hours_total": hours, "hours_done": 0.0, "units_done": 0,
		"unit_open": false, "unit_progress": 0.0, "q_sum": 0.0, "q_hours": 0.0, "min_q": float(tpl.get("min_q", 60)),
		"days": int(tpl.get("days", 10)), "deadline": 0, "pay": pay, "advance": int(round(pay * float(tpl.get("advance", 0.3)))),
		"rep": float(tpl.get("rep", 3)), "crate": {}, "crate_sent": (tpl.get("crate", {}) as Dictionary).duplicate(),
		"rare": (tpl.get("rare", {}) as Dictionary).duplicate(), "rare_in": {}, "masterpiece": {}, "status": "offered",
		"offered_day": Game.day(), "expires": Game.day() + int(_f("offer_days", 5.0)), "accepted_day": -1,
		"contrib": {}, "log": [], "late_noted": false, "blocker": ""}
	var mp: Variant = tpl.get("masterpiece", null)
	if mp is Dictionary and not (mp as Dictionary).is_empty():
		c["masterpiece"] = {"defs": (mp["defs"] as Array).duplicate(), "min_q": float(mp.get("min_q", 100)), "label": str(mp.get("label", "a masterpiece")), "uid": -1, "item": {}}
	return c


## Offers a template now (tests, the developer panel and on_day). Returns the offer or {"error": why}.
static func make_offer(tpl_id: String, why := "") -> Dictionary:
	var tpl := template(tpl_id)
	if tpl.is_empty():
		return {"error": "Unknown contract."}
	var c := _build(tpl, why if why != "" else _why_text(int(patron(str(tpl["patron"])).get("tier", 1))))
	offers().append(c)
	_announce(c)
	_changed()
	return c


static func _why_text(tier: int) -> String:
	var r: Array = standing()["reasons"].get(str(tier), [])
	if r.is_empty():
		return ""
	return "They write because " + _join_and(r) + "."


static func _join_and(a: Array) -> String:
	if a.size() <= 1:
		return "" if a.is_empty() else str(a[0])
	return ", ".join(PackedStringArray(a.slice(0, a.size() - 1).map(func(x): return str(x)))) + " and " + str(a[-1])


static func _announce(c: Dictionary) -> void:
	var pn := patron_name(str(c["patron"]))
	if Steward.smith_away():
		# Steward Mode: the letter waits sealed for the smith — only the sender is known, as on any envelope
		var sealed_line := "A messenger left a sealed letter from %s for the smith." % pn
		Events.toast.emit(sealed_line, "info")
		Game.journal(sealed_line)
		Chronicle.add("contract", sealed_line, {"contract": str(c["id"])})
		return
	var line := "A messenger brings a sealed letter from %s: %s." % [pn, c["title"]]
	Events.toast.emit(line + " Read it at your Project Bench or in the Workshop Ledger (Y).", "legendary" if str(patron(str(c["patron"])).get("kind", "")) == "royal" else "good")
	Game.journal(line + " " + str(c.get("why", "")))
	Chronicle.add("contract", line, {"contract": str(c["id"])})


## Can this template be offered now? (recipes known, patron not displeased, not already running)
static func _offerable(tpl: Dictionary) -> bool:
	for l in tpl.get("lines", []):
		if Crafting.recipe_locked_reason(str(l["recipe"])) != "":
			return false
	var pid := str(tpl.get("patron", ""))
	if favour(pid) <= -3:
		return false
	for c in active() + offers():
		if str(c["tpl"]) == str(tpl["id"]) or str(c["patron"]) == pid:
			return false
	var ps := _pst(pid)
	return Game.day() - int(ps.get("last_day", -99)) >= int(_f("offer_every", 6.0)) * 2


## Daily: letters (rare: one at a time, not before day `first_day`, at most every `offer_every` days, the highest
## tier the smith has earned first), expiring offers, late and withdrawn orders.
static func on_day() -> void:
	if Game.state.is_empty() or not Game.state.has("stats"):
		return
	var s := st()
	for o in offers().duplicate():
		if Game.day() > int(o.get("expires", 0)):
			o["status"] = "expired"
			offers().erase(o)
			Game.journal("The letter from %s went unanswered." % patron_name(str(o["patron"])))
	for c in active().duplicate():
		_check_deadline(c)
	if not offers().is_empty() or active().size() >= int(_f("max_active", 2.0)):
		return
	if Game.day() < int(_f("first_day", 4.0)) or Game.day() - int(s["last_offer_day"]) < int(_f("offer_every", 6.0)):
		return
	var tier := int(standing()["tier"])
	if tier <= 0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("contracts|%d|%d" % [Living.world_seed(), Game.day()])
	for t in range(tier, 0, -1):
		var pool := []
		for tpl in data().get("templates", []):
			if int(patron(str(tpl["patron"])).get("tier", 1)) == t and _offerable(tpl):
				pool.append(tpl)
		if pool.is_empty():
			continue
		var tpl: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
		s["last_offer_day"] = Game.day()
		make_offer(str(tpl["id"]))
		return


static func _check_deadline(c: Dictionary) -> void:
	var late := Game.day() - int(c["deadline"])
	if late > 0 and not bool(c.get("late_noted", false)):
		c["late_noted"] = true
		var line := "The deadline for %s has passed — %s waits, less patiently every day." % [c["title"], patron_name(str(c["patron"]))]
		Events.toast.emit(line, "bad")
		Game.journal(line)
	if late > int(_f("grace", 5.0)):
		_close(c, "failed", 0, -float(c["rep"]), -3, "%s withdrew the order «%s» — it was %d days late." % [patron_name(str(c["patron"])), c["title"], late])


# ======================================================================= accepting
## Accept an offer: the advance is paid and the patron's crate of ordinary materials arrives (once).
static func accept(id: String) -> String:
	var c := {}
	for o in offers():
		if str(o["id"]) == id:
			c = o
	if c.is_empty():
		return "That letter is no longer on the bench."
	if active().size() >= int(_f("max_active", 2.0)):
		return "You already have %d major contracts in hand." % active().size()
	offers().erase(c)
	c["status"] = "active"
	c["accepted_day"] = Game.day()
	c["deadline"] = Game.day() + int(c["days"])
	c["crate"] = (c["crate_sent"] as Dictionary).duplicate()
	active().append(c)
	_pst(str(c["patron"]))["last_day"] = Game.day()
	if int(c["advance"]) > 0:
		Game.add_gold(int(c["advance"]), "contract", "Advance: " + str(c["title"]), "patron:" + str(c["patron"]))
	_log(c, "Accepted on day %d; deadline day %d. %s sent a crate: %s." % [Game.day(), int(c["deadline"]), patron_name(str(c["patron"])), defs_text(c["crate"])])
	Lore.record("commission", "Brannoc accepted a major contract from %s: %s." % [patron_name(str(c["patron"])), c["title"]],
		{"importance": 1, "place": "brindlewick", "data": {"contract": id}, "chronicle": true})
	Events.toast.emit("Contract accepted — %d g advance. The patron's crate stands by the Project Bench." % int(c["advance"]), "good")
	_changed()
	return ""


static func decline(id: String) -> String:
	for o in offers():
		if str(o["id"]) == id:
			offers().erase(o)
			o["status"] = "declined"
			Game.journal("You declined %s's order: %s." % [patron_name(str(o["patron"])), o["title"]])
			_changed()
			return ""
	return "No such letter."


## Give the order up: the patron is displeased (as if it were withdrawn), the advance is kept, the crate goes back.
static func abandon(id: String) -> String:
	var c := _active(id)
	if c.is_empty():
		return "No such contract in hand."
	_close(c, "failed", 0, -float(c["rep"]), -3, "Brannoc gave up the order «%s» for %s." % [c["title"], patron_name(str(c["patron"]))])
	return ""


static func _active(id: String) -> Dictionary:
	for c in active():
		if str(c["id"]) == id:
			return c
	return {}


static func _log(c: Dictionary, text: String) -> void:
	var lg: Array = c["log"]
	lg.append({"day": Game.day(), "time": Game.time_string(), "text": text})
	while lg.size() > 40:
		lg.pop_front()


# ======================================================================= production
static func _line_of(c: Dictionary, unit_index: int) -> Dictionary:
	var i := unit_index
	for l in c["lines"]:
		if i < int(l["n"]):
			return l
		i -= int(l["n"])
	return {}


static func line_done(c: Dictionary, l: Dictionary) -> int:
	var before := 0
	for x in c["lines"]:
		if x == l:
			break
		before += int(x["n"])
	return clampi(int(c["units_done"]) - before, 0, int(l["n"]))


## The recipe that sets the skill and difficulty for apprentices (the hardest line) and the current line's recipe.
static func main_recipe(id: String) -> String:
	var c := get_c(id)
	var best := ""
	var bd := -1
	for l in c.get("lines", []):
		var d := Crafting.difficulty(str(l["recipe"]))
		if d > bd:
			bd = d
			best = str(l["recipe"])
	return best


static func current_recipe(c: Dictionary) -> String:
	var l := _line_of(c, mini(int(c["units_done"]), int(c["units_total"]) - 1))
	return str(l.get("recipe", ""))


## Materials a unit of a line needs (its recipe's inputs).
static func _unit_inputs(l: Dictionary) -> Dictionary:
	return DB.recipe(str(l.get("recipe", ""))).get("inputs", {})


static func _available(c: Dictionary, def: String) -> int:
	return int((c["crate"] as Dictionary).get(def, 0)) + Game.count(def)


## Why the next unit cannot be begun ("" = it can): its materials (crate first, then the stores) and, from the
## rare_at share of the order on, the rare materials.
static func next_unit_problem(c: Dictionary) -> String:
	if int(c["units_done"]) >= int(c["units_total"]):
		return "Every piece of the order is made — deliver it at the bench."
	if bool(c.get("unit_open", false)):
		return ""
	var miss := {}
	var ins := _unit_inputs(_line_of(c, int(c["units_done"])))
	for d in ins:
		var short := int(ins[d]) - _available(c, str(d))
		if short > 0:
			miss[str(d)] = short
	if not miss.is_empty():
		return "Missing materials for the next piece: " + defs_text(miss)
	var rm := rare_missing(c)
	if _rare_due(c) and not rm.is_empty():
		return "The rest of the order needs %s — see «How to get it»." % defs_text(rm)
	return ""


static func _rare_due(c: Dictionary) -> bool:
	return not (c["rare"] as Dictionary).is_empty() and float(c["units_done"]) >= floor(float(c["units_total"]) * _f("rare_at", 0.5))


## Rare materials still to be found ({def: n}), counting what is already laid in and what is in the stores.
static func rare_missing(c: Dictionary, count_stores := true) -> Dictionary:
	var out := {}
	for d in c["rare"]:
		var need := int(c["rare"][d]) - int((c["rare_in"] as Dictionary).get(d, 0)) - (Game.count(str(d)) if count_stores else 0)
		if need > 0:
			out[str(d)] = need
	return out


## Takes the materials of the next unit (the patron's crate first, then the stores) and, when due, the rare ones.
static func _begin_unit(c: Dictionary) -> bool:
	if next_unit_problem(c) != "":
		return false
	if _rare_due(c):
		for d in c["rare"]:
			var need := int(c["rare"][d]) - int((c["rare_in"] as Dictionary).get(d, 0))
			if need > 0 and Game.remove_def(str(d), need):
				c["rare_in"][str(d)] = int((c["rare_in"] as Dictionary).get(d, 0)) + need
				_log(c, "Laid in %d %s for the order." % [need, Guide.iname(str(d))])
	var ins := _unit_inputs(_line_of(c, int(c["units_done"])))
	var ks := ins.keys()
	ks.sort()
	for d in ks:
		var need := int(ins[d])
		var from_crate := mini(need, int((c["crate"] as Dictionary).get(d, 0)))
		if from_crate > 0:
			c["crate"][str(d)] = int(c["crate"][d]) - from_crate
			if int(c["crate"][str(d)]) <= 0:
				(c["crate"] as Dictionary).erase(str(d))
		if need - from_crate > 0:
			Game.remove_def(str(d), need - from_crate)
	c["unit_open"] = true
	c["unit_progress"] = 0.0
	return true


## Puts `hours` of work at craftsmanship `q` by `who` into the order. Returns the hours actually used (work stops
## when the next unit cannot be begun). Units complete as their hours fill.
static func add_hours(c: Dictionary, hours: float, q: float, who: String) -> float:
	var left := hours
	var used := 0.0
	while left > 0.0001 and int(c["units_done"]) < int(c["units_total"]):
		if not bool(c.get("unit_open", false)):
			if not _begin_unit(c):
				c["blocker"] = next_unit_problem(c)
				break
		var l := _line_of(c, int(c["units_done"]))
		var need := float(l["hpu"]) - float(c["unit_progress"])
		var step := minf(left, need)
		c["unit_progress"] = float(c["unit_progress"]) + step
		left -= step
		used += step
		if float(c["unit_progress"]) >= float(l["hpu"]) - 0.0001:
			c["units_done"] = int(c["units_done"]) + 1
			c["unit_open"] = false
			c["unit_progress"] = 0.0
	if used > 0.0:
		c["hours_done"] = float(c["hours_done"]) + used
		c["q_sum"] = float(c["q_sum"]) + q * used
		c["q_hours"] = float(c["q_hours"]) + used
		c["contrib"][who] = float((c["contrib"] as Dictionary).get(who, 0.0)) + used
		if int(c["units_done"]) >= int(c["units_total"]):
			c["blocker"] = ""
			var line := "The last piece of «%s» is done — deliver it at the Project Bench." % c["title"]
			_log(c, line)
			Events.toast.emit(line, "good")
		elif str(c.get("blocker", "")) != "" and next_unit_problem(c) == "":
			c["blocker"] = ""
	_changed()
	return used


## Why the smith cannot work a block now ("" = he can).
static func can_work(id: String) -> String:
	var c := _active(id)
	if c.is_empty():
		return "No such contract in hand."
	if not bench_installed():
		return "Set up a Project Bench in a workshop room first (Property & Workshop › Equipment)."
	if Vitality.fatigue() >= _f("exhausted", 92.0):
		return "You are too tired to work — sleep first."
	return next_unit_problem(c)


## The smith's craftsmanship for an hour on recipe `rid` (skill against difficulty, freshness, a little chance).
static func smith_hour_quality(rid: String, rng: RandomNumberGenerator = null) -> float:
	var qc: Dictionary = cfg("smith_quality", {})
	var lvl := Game.player_level(Crafting.recipe_skill(rid))
	var gap := clampi(lvl - Crafting.difficulty(rid), -6, 6)
	var q := float(qc.get("base", 80.0)) + float(qc.get("per_gap", 3.5)) * gap + float(qc.get("per_level", 0.5)) * lvl
	q -= (1.0 - Vitality.work_factor()) * float(qc.get("tired", 40.0))
	if rng != null:
		q += rng.randfn(0.0, float(qc.get("sd", 5.0)))
	return clampf(q, 20.0, 115.0)


## The smith's pace: an hour at the bench counts this many contract hours.
static func smith_pace(rid: String) -> float:
	var gap := clampi(Game.player_level(Crafting.recipe_skill(rid)) - Crafting.difficulty(rid), -5, 6)
	return maxf(0.5, (1.0 + _f("speed_per_gap", 0.04) * gap) * Vitality.work_factor())


## Work `hours` (a block) at the bench: each hour passes on the clock (apprentices work alongside), adds fatigue and
## puts the smith's hour into the order. Stops early when the next piece cannot be begun or he is spent.
static func work(id: String, hours: int) -> Dictionary:
	var why := can_work(id)
	if why != "":
		return {"error": why, "hours": 0, "units": 0, "quality": 0.0}
	var c := _active(id)
	var u0 := int(c["units_done"])
	var qs := 0.0
	var done := 0
	smith_working = true
	for h in maxi(1, hours):
		if done > 0 and can_work(id) != "":
			break
		var rid := current_recipe(c)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%s|%d|smith" % [id, Game.now()])
		var q := smith_hour_quality(rid, rng)
		var pace := smith_pace(rid)
		Game.advance_minutes(int(_f("hour_minutes", 60.0)))
		Vitality.add_fatigue(_f("fatigue_per_hour", 4.0))
		Game.grant_player_xp(Crafting.recipe_skill(rid), int(_f("xp_per_hour", 6.0)))
		if c.get("status", "") != "active":
			break
		add_hours(c, pace, q, "smith")
		qs += q
		done += 1
	smith_working = false
	var made := int(c["units_done"]) - u0
	if done > 0:
		_log(c, "You worked %d h at the bench: %d piece%s, ~%d%% craftsmanship." % [done, made, "" if made == 1 else "s", int(round(qs / done))])
	return {"hours": done, "units": made, "quality": qs / maxf(1.0, done), "error": ""}


# ======================================================================= apprentices (task kind "contract")
## The station an apprentice works the contract at: the bench, or one of the stations its recipes use — the first
## installed one nobody else holds (the smith keeps the bench while he works a block there).
static func stations(id: String) -> Array:
	var c := get_c(id)
	var out := [BENCH]
	for l in c.get("lines", []):
		for o in Crafting.operations(str(l["recipe"])):
			var s := str(o.get("station", ""))
			if not out.has(s):
				out.append(s)
	return out


static func work_station(id: String, worker := "") -> String:
	var first := ""
	for s in stations(id):
		if not Property.is_installed(s) or Crafting.station_locked_reason(s) != "":
			continue
		if s == BENCH and smith_working:
			continue
		if first == "":
			first = s
		var u := Apprentices.station_user(s)
		if u == "" or (worker != "" and u == worker):
			return s
	return first if first != "" else BENCH


## Why an apprentice cannot work an hour on this contract ("" = they can).
static func task_problem(id: String) -> String:
	var c := _active(id)
	if c.is_empty():
		return "The contract is no longer in hand."
	return next_unit_problem(c)


## An apprentice finished an hour at quality q: it goes into the order (their pace is already in the hour's length).
static func apprentice_hour(id: String, app: Dictionary, q: float) -> float:
	var c := _active(id)
	if c.is_empty():
		return 0.0
	var used := add_hours(c, 1.0, q, str(app.get("id", "")))
	if used > 0.0:
		_log(c, "%s worked an hour on the order (%d%%)." % [str(app.get("name", "")), int(round(q))])
	return used


static func finished_for_apprentices(id: String) -> bool:
	var c := _active(id)
	return c.is_empty() or int(c["units_done"]) >= int(c["units_total"])


# ======================================================================= the masterpiece
## Pieces in the stores that would serve as the order's masterpiece: the right kind, made by the smith himself,
## at least the craftsmanship asked.
static func masterpiece_candidates(id: String) -> Array:
	var c := get_c(id)
	var mp: Dictionary = c.get("masterpiece", {})
	if mp.is_empty():
		return []
	var out := []
	for it in Game.inventory():
		if (mp["defs"] as Array).has(str(it.get("def", ""))) and not bool(it.get("dev", false)):
			out.append(it)
	return out


static func masterpiece_reason(id: String, it: Dictionary) -> String:
	var mp: Dictionary = get_c(id).get("masterpiece", {})
	if mp.is_empty():
		return "This order asks for no masterpiece."
	if not (mp["defs"] as Array).has(str(it.get("def", ""))):
		return "The patron asked for %s." % mp["label"]
	if bool(it.get("dev", false)) or not Provenance.is_mine(it):
		return "It must be forged by your own hand."
	if float(it.get("quality", 0.0)) < float(mp["min_q"]):
		return "It needs %d%% craftsmanship (this one has %d%%)." % [int(mp["min_q"]), int(round(float(it.get("quality", 0.0))))]
	return ""


## Lays the masterpiece into the order: it leaves the stores and waits at the bench (same instance, same uid).
static func lay_in_masterpiece(id: String, uid: int) -> String:
	var c := _active(id)
	if c.is_empty():
		return "No such contract in hand."
	if c["masterpiece"].is_empty():
		return "This order asks for no masterpiece."
	if int(c["masterpiece"].get("uid", -1)) >= 0:
		return "The masterpiece is already laid in."
	var it := Game.find_uid(uid)
	if it.is_empty():
		return "That piece is not in your stores."
	var why := masterpiece_reason(id, it)
	if why != "":
		return why
	it = Game.take_uid(uid)
	c["masterpiece"]["uid"] = uid
	c["masterpiece"]["item"] = it
	Provenance.workshop(it, "commission", "Laid into the order «%s» for %s." % [c["title"], patron_name(str(c["patron"]))])
	_log(c, "Laid in the masterpiece: %s (%d%%)." % [Items.display_name(it), int(round(float(it.get("quality", 0.0))))])
	_changed()
	return ""


static func _return_masterpiece(c: Dictionary) -> void:
	var mp: Dictionary = c.get("masterpiece", {})
	if mp.is_empty() or (mp.get("item", {}) as Dictionary).is_empty():
		return
	var it: Dictionary = mp["item"]
	mp["item"] = {}
	mp["uid"] = -1
	Game.add_item(it, false)


# ======================================================================= delivery
static func ready(id: String) -> bool:
	var c := _active(id)
	return not c.is_empty() and int(c["units_done"]) >= int(c["units_total"])


static func quality(c: Dictionary) -> float:
	return float(c["q_sum"]) / float(c["q_hours"]) if float(c.get("q_hours", 0.0)) > 0.0 else 0.0


static func progress(c: Dictionary) -> float:
	return clampf(float(c["hours_done"]) / maxf(0.01, float(c["hours_total"])), 0.0, 1.0)


## The outcome the order would have if delivered now (for the view and for deliver()).
static func outcome_now(c: Dictionary) -> Dictionary:
	var q := quality(c)
	var late := maxi(0, Game.day() - int(c["deadline"]))
	var has_mp: bool = c["masterpiece"].is_empty() or int(c["masterpiece"].get("uid", -1)) >= 0
	var o := "good"
	if q < float(c["min_q"]):
		o = "poor"
	elif q >= float(c["min_q"]) + _f("excellent_margin", 12.0) and late == 0 and has_mp:
		o = "excellent"
	var f := 1.0
	match o:
		"poor":
			f = _f("poor_factor", 0.6)
		"excellent":
			f = _f("excellent_factor", 1.15)
	f *= maxf(0.5, 1.0 - _f("late_per_day", 0.1) * late)
	if not has_mp:
		f *= _f("missing_masterpiece", 0.85)
	var rest := maxi(0, int(round((int(c["pay"]) - int(c["advance"])) * f)))
	var rep := float(c["rep"])
	var r := rep if o == "excellent" else (rep * 0.6 if o == "good" else -rep * 0.5)
	if late > 0:
		r -= minf(rep, 1.0 * late)
	var fav: int = int({"excellent": 2, "good": 1, "poor": -1}.get(o, 0))
	if late > 0:
		fav -= 1
	return {"outcome": o, "pay": rest, "rep": r, "favour": fav, "late_days": late, "masterpiece": has_mp, "quality": q}


## Delivers a finished order: the rest of the pay, reputation, the patron's favour, the masterpiece to its new owner,
## leftover crate materials back to the patron, and the story (Lore / Chronicle / Hall of Fame for the finest).
static func deliver(id: String) -> Dictionary:
	var c := _active(id)
	if c.is_empty():
		return {"error": "No such contract in hand."}
	if not ready(id):
		return {"error": "%d of %d pieces made — the order is not finished." % [int(c["units_done"]), int(c["units_total"])]}
	var o := outcome_now(c)
	var pn := patron_name(str(c["patron"]))
	var mp_item: Dictionary = c["masterpiece"].get("item", {}) if not c["masterpiece"].is_empty() else {}
	var items := []
	if not mp_item.is_empty():
		Provenance.transfer(mp_item, "patron_" + str(c["patron"]), "commissioned", "brindlewick", "%s was delivered to %s with the order «%s»." % [Items.display_name(mp_item), pn, c["title"]])
		var ow: Array = Provenance.owners(mp_item)
		if not ow.is_empty():
			ow[-1]["name"] = str(patron(str(c["patron"])).get("name", pn))
		items.append(mp_item)
	var word := str(OUTCOME_WORD.get(o["outcome"], ""))
	var text := "Brannoc delivered «%s» to %s — %d pieces at %d%% craftsmanship%s%s. %s." % [c["title"], pn, int(c["units_total"]), int(round(float(o["quality"]))),
		(", %d day%s late" % [int(o["late_days"]), "" if int(o["late_days"]) == 1 else "s"]) if int(o["late_days"]) > 0 else ", on time",
		(" with " + Items.display_name(mp_item)) if not mp_item.is_empty() else "", word]
	_close(c, str(o["outcome"]), int(o["pay"]), float(o["rep"]), int(o["favour"]), text, items)
	return o


## Ends a contract: pay, reputation, favour, history, crate back, story.
static func _close(c: Dictionary, outcome: String, pay: int, rep: float, fav: int, text: String, items := []) -> void:
	active().erase(c)
	c["status"] = "delivered" if outcome != "failed" else "failed"
	c["outcome"] = outcome
	c["closed_day"] = Game.day()
	c["paid"] = pay
	c["rep_change"] = rep
	if outcome == "failed":
		_return_masterpiece(c)
	c["crate_returned"] = (c["crate"] as Dictionary).duplicate()
	c["crate"] = {}
	var pid := str(c["patron"])
	var ps := _pst(pid)
	ps["favour"] = clampi(int(ps["favour"]) + fav, -6, 10)
	ps["done"] = int(ps["done"]) + 1
	if outcome in ["excellent", "good"]:
		ps["good"] = int(ps["good"]) + 1
	ps["last_day"] = Game.day()
	if pay > 0:
		Game.add_gold(pay, "contract", "Contract delivered: " + str(c["title"]), "patron:" + str(c["patron"]))
	Shop.rep_change(rep, text)
	_log(c, text)
	var tier := int(patron(pid).get("tier", 1))
	var imp := 2 if outcome != "poor" else 1
	if tier >= 3 or outcome == "excellent":
		imp = 3
	Lore.record("commission", text, {"importance": imp, "items": items, "place": "brindlewick", "chronicle": true, "notable": true,
		"data": {"contract": str(c["id"]), "patron": pid, "outcome": outcome}})
	if outcome == "excellent" or (tier >= 3 and outcome == "good"):
		Recognition.record("commission", str(c["title"]), text, {"contract": str(c["id"]), "uid": int(c["masterpiece"].get("uid", -1)) if not c["masterpiece"].is_empty() else -1},
			"contract_" + str(c["id"]))
	# the masterpiece instance now belongs to the patron: it is kept whole in the holdings archive (never capped, same
	# uid, its story); this record keeps a reference to it
	var mpi: Variant = c["masterpiece"].get("item", {}) if not c["masterpiece"].is_empty() else {}
	if outcome != "failed" and mpi is Dictionary and not (mpi as Dictionary).is_empty() and not ItemRegistry.is_ref(mpi):
		ItemRegistry.archive(mpi, "patron_" + pid, str(patron(pid).get("name", pid)), "contract", {"contract": str(c["id"])})
		c["masterpiece"]["item"] = ItemRegistry.ref(mpi)
	history().append(c)
	while history().size() > 30:
		history().pop_front()
	var kind := "good" if outcome in ["excellent", "good"] else "bad"
	Events.toast.emit(text, "legendary" if outcome == "excellent" and tier >= 4 else kind)
	_changed()


# ======================================================================= presentation helpers
static func defs_text(m: Dictionary) -> String:
	var parts := PackedStringArray()
	var ks := m.keys()
	ks.sort()
	for d in ks:
		if int(m[d]) > 0:
			parts.append("%d %s" % [int(m[d]), Guide.iname(str(d))])
	return ", ".join(parts) if not parts.is_empty() else "nothing"


static func units_text(c: Dictionary) -> String:
	var parts := PackedStringArray()
	for l in c["lines"]:
		parts.append("%d %s" % [int(l["n"]), Guide.iname(str(l["def"])).to_lower() + ("s" if int(l["n"]) > 1 and not Guide.iname(str(l["def"])).ends_with("s") else "")])
	return " and ".join(parts)


## Every ordinary material the rest of the order needs ({def: n}), not counting what the current piece already took.
static func materials_needed(c: Dictionary) -> Dictionary:
	var out := {}
	var start := int(c["units_done"]) + (1 if bool(c.get("unit_open", false)) else 0)
	for i in range(start, int(c["units_total"])):
		var ins := _unit_inputs(_line_of(c, i))
		for d in ins:
			out[str(d)] = int(out.get(str(d), 0)) + int(ins[d])
	return out


## Who has put hours in: [{who, name, hours}] (the smith first).
static func contributors(c: Dictionary) -> Array:
	var out := []
	var ks: Array = (c["contrib"] as Dictionary).keys()
	ks.sort()
	if ks.has("smith"):
		ks.erase("smith")
		ks.push_front("smith")
	for k in ks:
		out.append({"who": str(k), "name": "You" if str(k) == "smith" else Talk.npc_name(str(k)), "hours": float(c["contrib"][k])})
	return out


## Open apprentice tasks working this contract.
static func tasks_for(id: String) -> Array:
	if not Game.state.has("apprentices"):
		return []
	return Apprentices.open_tasks().filter(func(t): return str(t.get("kind", "")) == "contract" and str(t.get("target", "")) == id)


## The prompt at the bench (WorldPrompts): what can be done right here.
static func prompt() -> Dictionary:
	var p := {"title": str(DB.station(BENCH).get("name", "Project Bench")), "actions": [], "status": "", "off": [], "note": "", "open": true, "text": ""}
	var ap := ApprenticeActors.station_prompt(BENCH, "")
	if ap != "":
		p["note"] = ap.trim_prefix(" — ")
	if not offers().is_empty():
		p["actions"].append("Read the letter (%s)" % str(patron(str(offers()[0]["patron"])).get("name", "")))
	if active().is_empty():
		if offers().is_empty():
			p["actions"].append("Contracts")
			p["off"].append("No major contract in hand — patrons write when your name grows")
		return p
	var c: Dictionary = active()[0]
	if ready(str(c["id"])):
		p["actions"].append("Deliver the order")
	else:
		var why := can_work(str(c["id"]))
		if why == "":
			p["actions"].append("Work on the contract (2 h)")
		else:
			p["off"].append(why)
	p["actions"].append("Inspect")
	p["status"] = "%d/%d pieces · due day %d" % [int(c["units_done"]), int(c["units_total"]), int(c["deadline"])]
	return p
