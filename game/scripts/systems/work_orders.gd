## WorkOrders — The Living Workshop C1: staged work orders on the workshop's existing task queue (canonical §4.4, D4, D8).
## EN: A task that makes a Design (craft, prep, commission — Apprentices.tasks) is a WORK ORDER: its operations are
##     grouped into STAGES — consecutive operations whose stations share a discipline, i.e. one profession's work (the
##     Emberwarden Longsword: smithing at forge and anvil · runecraft · alchemy · smithing at the wheel · stitching).
##     Each stage is done by an eligible worker (Workers.can_do per operation) at a real station instance, or claimed by
##     the smith, who then works it himself at the station with the existing checks (his craft job carries the order).
##     The order holds the materials from the moment the piece is begun (Apprentices: taken once, returned on cancel,
##     never taken again on a handoff, a reload or a claim), reserves the uid its piece will carry when it is created
##     (an order for equipment), and finishes through the one shared pipeline (Crafting.build) with that uid. The maker
##     is the worker of the forging stage — the stage of the Design's own discipline, its heaviest operation — never
##     whoever happens to finish; every other stage is recorded as a contribution (prov.contrib[] and one Lore event).
##     Workers hand the piece on between stages (the next one collects it from the last station), work in their own
##     hours, and an absent worker's stage is simply taken up by another eligible hand. A worker facing genuinely hard
##     work may ask the smith for a hand (D8: at most one request a day, it expires, it never blocks; declining costs
##     only the bonus). Ordinary one-discipline Designs stay one stage, one worker — exactly as before (§3.1).
##     State lives on the task: t["stages"], t["uid"], t["handoff"]; requests in Apprentices st()["help"].
## DA: Arbejdsordrer i etaper på værkstedets eksisterende opgavekø: hver faglig etape udføres af en kvalificeret
##     arbejder ved en rigtig station eller af smeden selv; samme uid fra ordre til færdig genstand; smeden bag
##     smedningen er mesteren; specialisternes bidrag noteres i proveniens og Lore; frivillige hjælpeanmodninger.
##
## Public API (static): is_order(t) staged(t) ensure(t) stages(t) stage_index(t, op) current(t) maker_stage(t)
##   stage_title(t, si) stage_stations(t, si) stage_reason(actor, t, si) who_can_stage(t, si) reserve_uid(t)
##   assign_stage(tid, si, actor) waiting_for_smith() begin_smith_stage(tid) smith_op_done(job, rec) smith_abandon(job)
##   on_op_finished(t, by) maker_of(t, finisher) contributions(t) record_contributions(it, t) stage_materials(t, si)
##   help() ask_help(t, a, op) answer_help(id, choice) migrate(data)
class_name WorkOrders
extends RefCounted

const KINDS := ["craft", "prep", "commission"]
const HANDOFF_MIN := 4.0          # collecting the half-made piece from the last station
const HELP_EXPIRE := 120          # minutes a help request stays open
const HELP_MINUTES := 30          # the smith's time at their side
const HELP_BONUS := 5.0           # craftsmanship of the operation he helped with
const HELP_GAP := 2               # asked only when the work is this much beyond the worker (difficulty − level)
const DISC_WORD := {"classic": "Smithing", "runecraft": "Rune work", "alchemy": "Alchemy", "stitching": "Leatherwork", "arcane": "Arcane work"}


# ======================================================================= shape
static func is_order(t: Dictionary) -> bool:
	return KINDS.has(str(t.get("kind", ""))) and str(t.get("recipe", "")) != "" and not DB.recipe(str(t["recipe"])).is_empty()


## The stages of a Design: consecutive operations at stations of one discipline.
static func plan(rid: String) -> Array:
	var out := []
	var ops := Crafting.operations(rid)
	for i in ops.size():
		var disc := str(DB.station(str(ops[i].get("station", ""))).get("discipline", "classic"))
		if out.is_empty() or str(out[-1]["disc"]) != disc:
			out.append({"i": out.size(), "disc": disc, "ops": [i], "profession": Workers.discipline_profession(disc),
				"skill": str(Crafting.DISCIPLINE_SKILL.get(disc, "smithing")), "state": "waiting", "assignee": "", "by": "", "q": 0.0,
				"at": "", "started": -1, "finished": -1})
		else:
			(out[-1]["ops"] as Array).append(i)
	return out


## The task's stages (built on first use when its Design is known; consistent with a task already under way).
static func stages(t: Dictionary) -> Array:
	ensure(t)
	return t.get("stages", [])


static func staged(t: Dictionary) -> bool:
	return is_order(t) and stages(t).size() > 1


## Builds t["stages"] for a Design task that has none (new orders, a commission whose Design was just chosen, saves
## from before work orders): the stages before the current operation are done by whoever worked them (ops_done), the
## current one is ready or being worked. Idempotent; a task whose Design changed is rebuilt.
static func ensure(t: Dictionary) -> void:
	if not is_order(t):
		return
	var rid := str(t["recipe"])
	if t.has("stages") and str(t.get("stages_for", "")) == rid:
		return
	var st := plan(rid)
	var op := int(t.get("op", 0))
	var done: Array = t.get("ops_done", [])
	for s in st:
		var ops: Array = s["ops"]
		if int(ops[-1]) < op:
			s["state"] = "done"
			var qs := 0.0
			var n := 0
			var by := ""
			for i in ops:
				if int(i) < done.size():
					qs += float(done[int(i)].get("q", 0.0))
					n += 1
					if by == "":
						by = str(done[int(i)].get("by", ""))
			s["q"] = qs / float(maxi(1, n))
			s["by"] = by
		elif int(ops[0]) <= op:
			s["state"] = "working" if bool(t.get("started", false)) and str(t.get("worker", "")) != "" else "ready"
	t["stages"] = st
	t["stages_for"] = rid


## The index of the stage that holds operation `op` (default: the task's current operation).
static func stage_index(t: Dictionary, op := -1) -> int:
	var o := int(t.get("op", 0)) if op < 0 else op
	var st := stages(t)
	for s in st:
		if (s["ops"] as Array).has(o):
			return int(s["i"])
	return st.size() - 1 if o >= 0 and not st.is_empty() else 0


static func current(t: Dictionary) -> Dictionary:
	var st := stages(t)
	if st.is_empty():
		return {}
	return st[clampi(stage_index(t), 0, st.size() - 1)]


## The forging stage: the first stage of the Design's own discipline (the smithing of a blade), else the heaviest.
static func maker_stage(t: Dictionary) -> int:
	var st := stages(t)
	var disc := str(DB.recipe(str(t.get("recipe", ""))).get("discipline", "classic"))
	for s in st:
		if str(s["disc"]) == disc:
			return int(s["i"])
	var ops := Crafting.operations(str(t.get("recipe", "")))
	var best := 0
	var bw := -1.0
	for s2 in st:
		var w := 0.0
		for i in s2["ops"]:
			w += float(ops[int(i)].get("weight", 1.0))
		if w > bw:
			bw = w
			best = int(s2["i"])
	return best


## "Smithing — forge, anvil" / "Rune work — rune engraving stand".
static func stage_title(t: Dictionary, si: int) -> String:
	var st := stages(t)
	if si < 0 or si >= st.size():
		return ""
	var names := PackedStringArray()
	for sid in stage_stations(t, si):
		names.append(str(DB.station(str(sid)).get("name", sid)).to_lower())
	return "%s — %s" % [str(DISC_WORD.get(str(st[si]["disc"]), "Work")), ", ".join(names)]


## The station types a stage is worked at, in order, each once.
static func stage_stations(t: Dictionary, si: int) -> Array:
	var out := []
	var st := stages(t)
	if si < 0 or si >= st.size():
		return out
	var ops := Crafting.operations(str(t.get("recipe", "")))
	for i in st[si]["ops"]:
		var sid := str(ops[int(i)].get("station", ""))
		if not out.has(sid):
			out.append(sid)
	return out


## The Design's materials a stage puts into the piece (for the Ledger): each input goes to the first stage of the
## discipline that makes it (a runestone to the rune stage, a coating to the alchemy stage), else to the first stage.
static func stage_materials(t: Dictionary, si: int) -> Dictionary:
	var out := {}
	var rid := str(t.get("recipe", ""))
	var st := stages(t)
	var inputs: Dictionary = DB.recipe(rid).get("inputs", {})
	for d in inputs:
		var made_by := _input_discipline(str(d))
		var to := 0
		for s in st:
			if str(s["disc"]) == made_by and made_by != str(DB.recipe(rid).get("discipline", "")):
				to = int(s["i"])
				break
		if to == si:
			out[str(d)] = int(inputs[d])
	return out


## The craft a material belongs to (for the Ledger only): the discipline of a Design that makes it, else by its kind
## (threads, leather and cloth → leatherwork; runestones → rune work; coatings, oils, potions → alchemy).
const INPUT_PREFIX := {"thread_": "stitching", "leather_": "stitching", "cloth_": "stitching", "hide_": "stitching", "runestone_": "runecraft",
	"coating_": "alchemy", "oil_": "alchemy", "potion_": "alchemy", "infusion_": "alchemy"}


static func _input_discipline(d: String) -> String:
	for r in DB.recipes.values():
		if str(r.get("output", "")) == d:
			return str(r.get("discipline", ""))
	for p in INPUT_PREFIX:
		if d.begins_with(str(p)):
			return str(INPUT_PREFIX[p])
	return ""


# ======================================================================= who may do a stage
## May `actor` work this stage? Each of its operations (Workers.can_do: the workshop's knowledge, the actor's competence
## in that station's craft, the station). Apprentices: the forging stage makes them the maker, so their rank's rules
## for the whole Design apply; a contributing stage only asks that its craft is within their rank (their own
## profession's always is). "" = yes.
static func stage_reason(actor: Variant, t: Dictionary, si: int) -> String:
	var st := stages(t)
	if si < 0 or si >= st.size():
		return "No such stage."
	var rid := str(t.get("recipe", ""))
	for i in st[si]["ops"]:
		var why := Workers.can_do(actor, {"recipe": rid, "op": int(i)})
		if why != "":
			return why
	var a := Workers.resolve(actor)
	if str(a["kind"]) == "apprentice":
		var app: Dictionary = a["data"]
		if si == maker_stage(t) or not staged(t):
			return Apprentices.rank_reason(app, rid)
		var disc := str(st[si]["disc"])
		var rd := Apprentices.rank_data(str(app.get("rank", "novice")))
		if Workers.discipline_of(Workers.profession(app)) != disc and not (rd.get("disciplines", []) as Array).has(disc):
			return "%s is beyond a %s." % [str(Crafting.DISCIPLINE_NAME.get(disc, disc)), str(rd.get("name", "novice")).to_lower()]
	return ""


## Every workshop worker who may do the stage (the smith first). Only the smith and the workshop's employees take
## stages — never anyone else the workshop's actor list may include (a helping spouse serves at the counter).
static func who_can_stage(t: Dictionary, si: int) -> Array:
	var out := []
	for id in Workers.workshop_actors():
		if not Workers.kind(str(id)) in ["player", "apprentice"]:
			continue
		if stage_reason(str(id), t, si) == "":
			out.append(str(id))
	return out


## Why nobody on the staff can do the current stage, naming the profession and whether the smith could ("" = someone can).
static func staff_gap(t: Dictionary, si: int) -> String:
	var who := who_can_stage(t, si)
	if who.size() > (1 if who.has("player") else 0):
		return ""
	var s: Dictionary = stages(t)[si]
	var need := "Needs %s for %s" % [Workers.a_noun(str(s["profession"])), stage_title(t, si).to_lower()]
	if who.has("player"):
		return need + " — nobody on the staff can; claim the stage and do it yourself, or take one on at the notice board."
	return need + " — " + stage_reason("player", t, si).trim_suffix(".") + "; take one on at the notice board."


## A new piece of the order (Apprentices._reset_iteration): every stage waits again (the first is ready); who is pinned
## to a stage or claimed it stays.
static func reset(t: Dictionary) -> void:
	if not t.has("stages"):
		return
	for s in t["stages"]:
		for k in ["by_name", "by_mark", "by_rank", "by_rank_name", "by_level", "by_profession", "steward"]:
			(s as Dictionary).erase(k)
		s["state"] = "ready" if int(s["i"]) == 0 else "waiting"
		s["by"] = ""
		s["q"] = 0.0
		s["at"] = ""
		s["started"] = -1
		s["finished"] = -1


# ======================================================================= the piece's identity
## An order for equipment reserves the uid its piece will carry, once, when it is created (and for each further piece
## of a repeated order when the previous one is finished). Materials and stackable goods take theirs at completion.
static func reserve_uid(t: Dictionary) -> void:
	if int(t.get("uid", 0)) > 0:
		return
	var out := ""
	if str(t.get("recipe", "")) != "":
		out = str(DB.recipe(str(t["recipe"])).get("output", ""))
	if str(t.get("kind", "")) == "commission" or (out != "" and Items.is_equipment({"def": out})):
		t["uid"] = Game.new_uid()


# ======================================================================= assigning and claiming
## Pins a stage to a worker: an apprentice id, "player" (the smith claims it and will do it himself), or "" (automatic).
## Not while someone is in the middle of that stage's operation. "" or why not.
static func assign_stage(tid: int, si: int, actor: String) -> String:
	var t := Apprentices.task(tid)
	if t.is_empty() or str(t.get("state", "")) in Apprentices.FINISHED or not is_order(t):
		return "No such open work order."
	var st := stages(t)
	if si < 0 or si >= st.size():
		return "No such stage."
	var s: Dictionary = st[si]
	if str(s["state"]) == "done":
		return "That stage is already done."
	var who := "player" if actor in ["player", "smith"] else actor
	if who != "":
		var why := stage_reason(who, t, si)
		if why != "":
			return why
	var cur := stage_index(t) == si
	if cur and str(t.get("worker", "")) != "" and str(t.get("worker", "")) != who:
		if str(t["worker"]) == "player":
			return "You are working this stage — finish or abandon it at the station first."
		if float(t.get("progress", 0.0)) > 0.0 and str(t.get("station", "")) != "":
			return "%s is in the middle of it — wait for the operation to finish." % str(Apprentices.get_a(str(t["worker"])).get("name", "Someone"))
		var wa := Apprentices.get_a(str(t["worker"]))
		if not wa.is_empty():
			wa["task"] = -1
		t["worker"] = ""
		t["station"] = ""
		t["at"] = ""
	s["assignee"] = who
	if cur and who == "player":
		t["blocker"] = _smith_blocker(t)
	Apprentices.note_changed()
	return ""


static func _smith_blocker(t: Dictionary) -> String:
	var op: Dictionary = Crafting.operations(str(t["recipe"]))[mini(int(t.get("op", 0)), Crafting.operations(str(t["recipe"])).size() - 1)]
	return "Waiting for you: %s at %s (you claimed this stage)." % [str(op.get("op", "the work")).to_lower(), Smithy.station_ref(str(op.get("station", "")))]


## The first open order whose current stage the smith claimed and may begin now: {task, stage, op, station (type)}.
static func waiting_for_smith() -> Dictionary:
	if Game.state.is_empty() or not Game.state.has("apprentices"):
		return {}
	for t in Apprentices.open_tasks():
		if not is_order(t) or str(t.get("worker", "")) != "":
			continue
		var s := current(t)
		if s.is_empty() or str(s.get("assignee", "")) != "player":
			continue
		if not bool(t.get("started", false)) and not Crafting.missing_inputs(str(t["recipe"])).is_empty():
			continue
		var op: Dictionary = Crafting.operations(str(t["recipe"]))[int(t.get("op", 0))]
		return {"task": int(t["id"]), "stage": int(s["i"]), "op": int(t.get("op", 0)), "station": str(op.get("station", ""))}
	return {}


## The smith begins the stage he claimed: the order's materials are taken now if the piece is new (once — never again
## for later stages), and his craft job carries the order (Crafting.record_step then records each operation into the
## order). His job runs from the current operation to the end of the stage. "" or why not.
static func begin_smith_stage(tid: int, under_steward := false) -> String:
	var t := Apprentices.task(tid)
	if t.is_empty() or str(t.get("state", "")) in Apprentices.FINISHED or not is_order(t):
		return "No such open work order."
	if Crafting.active():
		return "Finish the current work first."
	if Steward.smith_away() and not under_steward:
		return "The steward runs the workshop — take it back first."
	var s := current(t)
	if str(s.get("assignee", "")) != "player":
		return "That stage is not yours — claim it first."
	if str(t.get("worker", "")) != "":
		return "Someone is at work on it."
	var why := stage_reason("player", t, int(s["i"]))
	if why != "":
		return why
	var prob := Apprentices.task_problem(t)
	if prob != "":
		return prob
	if not bool(t.get("started", false)):
		Apprentices.begin_piece(t, "player")
	var ops: Array = s["ops"]
	Game.state["craft"] = {"recipe": str(t["recipe"]), "step": int(t.get("op", 0)), "samples": [], "ops": [], "awaiting_dice": false,
		"day": Game.day(), "order": tid, "stage": int(s["i"]), "stop": int(ops[-1]) + 1}
	t["worker"] = "player"
	t["state"] = "working"
	t["blocker"] = ""
	t["fetch"] = 0.0
	t.erase("handoff")
	s["state"] = "working"
	if int(s.get("started", -1)) < 0:
		s["started"] = Game.now()
	Apprentices.log_line("player", "The smith took up the %s of %s." % [stage_title(t, int(s["i"])).to_lower(), str(t.get("label", ""))])
	Apprentices.note_changed()
	Events.crafting_changed.emit()
	return ""


## Crafting.record_step on a job that carries an order: the operation goes into the order (who, where, how well), the
## order moves on, and at the end of his stage the piece is handed on (or finished when it was the last stage).
static func smith_op_done(j: Dictionary, rec: Dictionary) -> void:
	var t := Apprentices.task(int(j.get("order", -1)))
	if t.is_empty() or str(t.get("state", "")) in Apprentices.FINISHED:
		Game.state["craft"] = {}
		return
	var r := rec.duplicate(true)
	r["by"] = "player"
	if Steward.marked(j):
		r["steward"] = true
	(t["ops_done"] as Array).append(r)
	t["op"] = int(j["step"])
	var si := int(j.get("stage", 0))
	var st := stages(t)
	if si >= 0 and si < st.size():
		st[si]["at"] = str(r.get("at", r.get("station", "")))
	if int(j["step"]) < int(j.get("stop", 0)):
		return   # more of his stage to do (the next operation, perhaps at another station)
	Game.state["craft"] = {}
	t["worker"] = ""
	_stage_done(t, si, "player")
	if int(t["op"]) >= Crafting.operations(str(t["recipe"])).size():
		Apprentices.complete_order(t, {})
	else:
		_handoff(t, si, "player")
	Apprentices.note_changed()


## He abandons his stage at the station (Crafting.cancel): the operations already recorded stay in the order, the
## materials stay with the order, the stage waits for him again (or for whoever it is given to).
static func smith_abandon(j: Dictionary) -> void:
	var t := Apprentices.task(int(j.get("order", -1)))
	Game.state["craft"] = {}
	if t.is_empty():
		return
	if str(t.get("worker", "")) == "player":
		t["worker"] = ""
		t["state"] = "queued"
		var s := current(t)
		if not s.is_empty() and str(s["state"]) == "working":
			s["state"] = "ready"
		t["blocker"] = _smith_blocker(t)
	Apprentices.note_changed()


# ======================================================================= handoffs
## Called after an apprentice finished an operation (t["op"] already advanced). At a stage boundary the stage is done
## and the piece is handed on: returns true when the worker lets go of the order.
static func on_op_finished(t: Dictionary, by: String) -> bool:
	if not staged(t):
		return false
	var prev := stage_index(t, int(t["op"]) - 1)
	var ops_n := Crafting.operations(str(t["recipe"])).size()
	if int(t["op"]) >= ops_n:
		_stage_done(t, prev, by)
		return false   # the piece is finished (Apprentices._complete)
	var now_si := stage_index(t)
	if now_si == prev:
		return false
	_stage_done(t, prev, by)
	_handoff(t, prev, by)
	return true


static func _stage_done(t: Dictionary, si: int, by: String) -> void:
	var st := stages(t)
	if si < 0 or si >= st.size():
		return
	var s: Dictionary = st[si]
	var qs := 0.0
	var n := 0
	for i in s["ops"]:
		if int(i) < (t["ops_done"] as Array).size():
			qs += float(t["ops_done"][int(i)].get("q", 0.0))
			n += 1
	s["state"] = "done"
	s["q"] = qs / float(maxi(1, n))
	s["by"] = by
	var last := int((s["ops"] as Array)[-1])
	if last < (t["ops_done"] as Array).size():
		var lo: Dictionary = t["ops_done"][last]
		s["at"] = str(lo.get("at", lo.get("station", s.get("at", ""))))   # the station (instance) it was finished at
	s["finished"] = Game.now()
	var a := Workers.resolve(by)
	s["by_name"] = str(a.get("name", ""))
	if str(a["kind"]) == "apprentice":
		var app: Dictionary = a["data"]
		s["by_mark"] = str(app.get("mark", {}).get("id", by))
		s["by_rank"] = str(app.get("rank", ""))
		s["by_rank_name"] = Apprentices.rank_name(app)
		s["by_level"] = Apprentices.level(app, Crafting.recipe_skill(str(t["recipe"])))
		s["by_profession"] = Workers.profession(app)
	elif str(a["kind"]) == "player":
		s["by_profession"] = "blacksmith"
		var marked := false
		for i2 in s["ops"]:
			if int(i2) < (t["ops_done"] as Array).size() and bool(t["ops_done"][int(i2)].get("steward", false)):
				marked = true
		s["steward"] = marked


## The piece goes on to the next stage: whoever takes it collects it from the station of the last operation.
static func _handoff(t: Dictionary, from_si: int, by: String) -> void:
	var st := stages(t)
	var nx := stage_index(t)
	if nx >= 0 and nx < st.size():
		st[nx]["state"] = "ready"
	var out := str(DB.recipe(str(t["recipe"])).get("output", ""))
	t["handoff"] = {"from": by, "at": str(st[from_si].get("at", "")) if from_si >= 0 and from_si < st.size() else "", "piece": out}
	t["fetch"] = 0.0
	t["walk"] = Apprentices.WALK_MIN
	var who := Workers.resolve(by)
	var nxt_title := stage_title(t, nx).to_lower()
	Apprentices.log_line(by if str(who["kind"]) == "apprentice" else "player", "%s handed %s on for the %s." % [
		"The smith" if str(who["kind"]) == "player" else str(who.get("name", "Someone")), str(DB.item(out).get("name", "the piece")).to_lower(), nxt_title])
	if nx >= 0 and nx < st.size() and str(st[nx].get("assignee", "")) == "player":
		t["blocker"] = _smith_blocker(t)
		Events.toast.emit("%s is ready for your %s." % [str(t.get("label", "The order")), nxt_title], "info")


# ======================================================================= the maker and the contributors
## Who made the piece: the worker of the forging stage's heaviest operation (PROD-010: never simply the last hand).
## {kind "player"|"apprentice", id, name, mark, rank, rank_name, level, app (the live record or {}), steward}.
static func maker_of(t: Dictionary, finisher: Dictionary) -> Dictionary:
	var by := ""
	var done: Array = t.get("ops_done", [])
	if is_order(t):
		var ms := maker_stage(t)
		var ops := Crafting.operations(str(t["recipe"]))
		var bw := -1.0
		var mops: Array = stages(t)[ms]["ops"] if ms < stages(t).size() else []
		for i in mops:
			if int(i) < done.size() and float(ops[int(i)].get("weight", 1.0)) > bw:
				bw = float(ops[int(i)].get("weight", 1.0))
				by = str(done[int(i)].get("by", ""))
	if by == "":
		by = str(finisher.get("id", "player")) if not finisher.is_empty() else "player"
	if by in ["player", "smith"]:
		var marked := done.any(func(o): return str(o.get("by", "")) == "player" and bool(o.get("steward", false)))
		return {"kind": "player", "id": "player", "name": Provenance.SMITH_NAME, "app": {}, "steward": marked}
	var app := Apprentices.get_a(by)
	if not app.is_empty():
		return {"kind": "apprentice", "id": by, "name": str(app["name"]), "mark": str(app["mark"]["id"]), "rank": str(app["rank"]),
			"rank_name": Apprentices.rank_name(app), "level": Apprentices.level(app, Crafting.recipe_skill(str(t.get("recipe", "")))), "app": app}
	# the maker has left the workshop since: the stage keeps who they were
	for s in stages(t):
		if str(s.get("by", "")) == by:
			return {"kind": "apprentice", "id": by, "name": str(s.get("by_name", by)), "mark": str(s.get("by_mark", by)), "rank": str(s.get("by_rank", "")),
				"rank_name": str(s.get("by_rank_name", "apprentice")), "level": int(s.get("by_level", 0)), "app": {}}
	return {"kind": "apprentice", "id": by, "name": by, "mark": by, "rank": "", "rank_name": "apprentice", "level": 0, "app": {}}


## The stages worked by someone other than the maker: [{who, name, profession, stage, title, stations, at, quality, day}].
static func contributions(t: Dictionary, maker_id: String) -> Array:
	var out := []
	if not staged(t):
		return out
	var ops := Crafting.operations(str(t["recipe"]))
	for s in stages(t):
		var by := str(s.get("by", ""))
		if by == "" or by == maker_id or (by in ["player", "smith"] and maker_id in ["player", "smith"]):
			continue
		var names := []
		for sid in stage_stations(t, int(s["i"])):
			names.append(str(sid))
		var opnames := PackedStringArray()
		for i in s["ops"]:
			opnames.append(str(ops[int(i)].get("op", "")))
		out.append({"who": "smith" if by == "player" else by, "name": str(s.get("by_name", Workers.resolve(by).get("name", by))),
			"profession": str(s.get("by_profession", Workers.profession(by))), "stage": int(s["i"]), "title": stage_title(t, int(s["i"])),
			"work": "; ".join(opnames), "stations": names, "at": str(s.get("at", "")), "quality": snappedf(float(s.get("q", 0.0)), 0.1),
			"day": int(float(int(s.get("finished", Game.now()))) / 1440.0) + 1})
	return out


## Writes the contributions on the finished piece (Provenance.add_contributions + one Lore event) and in each
## contributor's memory. Returns them.
static func record_contributions(it: Dictionary, t: Dictionary, maker: Dictionary) -> Array:
	var c := contributions(t, str(maker.get("id", "")))
	if c.is_empty() or it.is_empty():
		return c
	Provenance.add_contributions(it, c, str(maker.get("name", "")))
	for e in c:
		var app := Apprentices.get_a(str(e["who"]))
		if not app.is_empty():
			Apprentices.remember(app, "Did the %s of %s on day %d (%d%%) — %s made it." % [str(e["title"]).to_lower(), Items.display_name(it), Game.day(),
				int(round(float(e["quality"]))), str(maker.get("name", "the smith"))], int(it.get("uid", -1)), "contributed")
			app["contribs"] = int(app.get("contribs", 0)) + 1
	return c


# ======================================================================= help requests (D8)
static func help() -> Array:
	return Apprentices.st()["help"]


static func open_help() -> Array:
	return help().filter(func(h): return str(h.get("state", "")) == "open" and int(h.get("expires", 0)) > Game.now())


## A worker about to do genuinely hard work (the operation is HELP_GAP beyond their skill) may ask the smith for a hand:
## at most one request a day, never while the steward runs the forge (the smith is away), never blocking the work.
static func ask_help(t: Dictionary, a: Dictionary, op: Dictionary) -> void:
	if Steward.smith_away() or int(Apprentices.st().get("help_day", -1)) == Game.day() or a.is_empty():
		return
	var rid := str(t.get("recipe", ""))
	if rid == "":
		return
	var sk := Apprentices.op_skill(rid, str(op.get("station", "")))
	var gap := Crafting.difficulty(rid) - Apprentices.level(a, sk)
	if gap < HELP_GAP:
		return
	var st := Apprentices.st()
	st["help_day"] = Game.day()
	var id := int(st.get("next_help", 1))
	st["next_help"] = id + 1
	var text := "%s asks for a hand: %s at the %s is hard work for them (%s %d, the Design asks %d)." % [str(a["name"]).split(" ")[0],
		str(op.get("op", "the work")).to_lower(), Apprentices._place_name(str(t.get("at", op.get("station", "")))), SkillSys.skill_name(sk),
		Apprentices.level(a, sk), Crafting.difficulty(rid)]
	help().append({"id": id, "task": int(t["id"]), "op": int(t.get("op", 0)), "app": str(a["id"]), "skill": sk, "made": Game.now(),
		"expires": Game.now() + HELP_EXPIRE, "state": "open", "text": text, "day": Game.day()})
	while help().size() > 20:
		help().pop_front()
	Apprentices.log_line(str(a["id"]), text)
	Events.toast.emit(text + " (Workshop Ledger — optional)", "info")


## The smith answers: "help" (half an hour at their side: a better operation, a little loyalty) or "decline" (they carry
## on alone, without the bonus). "" or why not.
static func answer_help(id: int, choice: String) -> String:
	for h in help():
		if int(h.get("id", -1)) != id:
			continue
		if str(h["state"]) != "open" or int(h.get("expires", 0)) <= Game.now():
			return "That request has lapsed — they carried on alone."
		if choice == "decline":
			h["state"] = "declined"
			Apprentices.note_changed()
			return ""
		if choice != "help":
			return "Choose help or decline."
		if Steward.smith_away():
			return "The smith is away while the steward runs the workshop."
		var t := Apprentices.task(int(h["task"]))
		if t.is_empty() or str(t.get("state", "")) in Apprentices.FINISHED or int(t.get("op", -1)) != int(h["op"]):
			h["state"] = "lapsed"
			return "That work is already past."
		h["state"] = "helped"
		t["helped_op"] = int(h["op"])
		t["supervised"] = true
		var a := Apprentices.get_a(str(h["app"]))
		if not a.is_empty():
			a["loyalty"] = clampf(float(a.get("loyalty", 50.0)) + 2.0, 0.0, 100.0)
			Apprentices.remember(a, "The smith came over to help with the %s on day %d." % [str(h.get("skill", "work")).replace("_", " "), Game.day()])
			Apprentices.log_line(str(a["id"]), "The smith lent %s a hand." % str(a["name"]).split(" ")[0])
		Game.grant_player_xp(str(h.get("skill", "smithing")), 3)
		Game.advance_minutes(HELP_MINUTES)
		Apprentices.note_changed()
		return ""
	return "No such request."


# ======================================================================= save step
## Save step "station instances and work orders" on raw data: every open Design task gains its stages (consistent with
## how far it is) and, when it makes equipment, the uid its piece will carry. Idempotent. Returns the number converted.
static func migrate(data: Dictionary) -> int:
	var ap: Variant = data.get("apprentices")
	if not ap is Dictionary or not (ap as Dictionary).get("tasks") is Array:
		return 0
	var n := 0
	var prev: Dictionary = Game.state
	Game.state = data
	for t in (ap as Dictionary)["tasks"]:
		if not t is Dictionary or str(t.get("state", "")) in Apprentices.FINISHED or not is_order(t):
			continue
		var changed := false
		if not (t as Dictionary).has("stages"):
			ensure(t)
			changed = true
		if int(t.get("uid", 0)) <= 0 and data.has("next_uid"):
			reserve_uid(t)
			changed = changed or int(t.get("uid", 0)) > 0
		if changed:
			n += 1
	Game.state = prev
	return n
