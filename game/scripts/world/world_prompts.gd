## WorldPrompts — what the smith can do with the thing he faces, in a few words.
## EN: Builds the interaction prompt for a world interactable or a person: a title, at most four available actions
##     (shown after the interact key), an optional status ("open until 19:00"), and at most two greyed lines for
##     actions that are not possible right now, each with a short reason ("Closed — opens 7:00",
##     "Offer gear — nothing in your stores"). Unknown kinds keep their plain label. VillageWorld asks for a prompt
##     when the focus changes (and refreshes it now and then); UIRoot draws it. Pure: no side effects, testable.
## DA: Interaktionsprompten: titel, få tilgængelige handlinger, status og nedtonede utilgængelige handlinger med grund.
##
## Public API (static):
##   for_entity(e: Dictionary, area := "village") -> Dictionary
##       {title, actions: Array[String], status: String, off: Array[String], note: String, open: bool, text: String}
##   npc_actions(npc, area := "village") -> Dictionary {actions, off}
##   line(p) -> String     the main line as the HUD shows it ("Pell's Provisions — [E] Buy (open until 19:00)")
class_name WorldPrompts
extends RefCounted

const MAX_ACTIONS := 4
const MAX_OFF := 2

## Short verbs for dialogue options (first mention wins; options without a verb stay in the dialogue only).
const VERBS := {"delivery": "Take delivery", "serve": "Sell", "serve_repair": "Repair", "refund": "Settle dispute",
	"refuse": "Settle dispute", "talk": "Talk", "manage": "Work orders", "equip": "Offer gear", "order": "Commission?",
	"shop_counter": "Buy", "c_rival_shop": "Buy", "c_pawn": "Pawn", "c_caravan": "Buy", "c_creatures": "Creatures",
	"ironfront_play": "Ironfront", "ironfront_teach": "Ironfront", "ironfront_intro": "Ironfront", "meal": "Meal",
	"ale": "Buy a round", "drink": "Drink", "dice": "Knucklebones", "rumour": "Rumours", "evening": "Evening"}

## What a counter offers when it is open.
const VENUE_ACTIONS := {"general_store": ["Buy"], "herbalist": ["Buy"], "harbour": ["Ships", "Imports"],
	"pawn": ["Pawn", "Sell", "Buy"], "rival_smith": ["Buy"], "creatures": ["Buy creatures"], "caravan": ["Buy", "Sell wanted goods"],
	"notice": ["Applicants", "Commissions", "Upgrades"]}


static func _p(title: String) -> Dictionary:
	return {"title": title, "actions": [], "status": "", "off": [], "note": "", "open": true, "text": ""}


static func for_entity(e: Dictionary, area := "village") -> Dictionary:
	var kind := str(e.get("kind", ""))
	var id := str(e.get("id", ""))
	if kind == "npc":
		return _npc(id, area)
	if kind == "station":
		return _station(id)
	var vid := Venues.venue_for_entity(kind, id)
	if vid != "":
		return _venue(vid)
	if kind == "counter":
		return _shop_counter()
	var p := _p("")
	p["text"] = str(e.get("label", ""))
	return p


# ------------------------------------------------------------------ venues
static func _venue(vid: String) -> Dictionary:
	var v := Venues.get_v(vid)
	var p := _p(str(v.get("name", vid)))
	if not Venues.is_open(vid):
		p["open"] = false
		p["status"] = Venues.status_text(vid)
		return p
	var acts: Array = (VENUE_ACTIONS.get(vid, ["Use"]) as Array).duplicate()
	if vid == "harbour":
		var n := Trade.deliveries().size()
		if n > 0:
			acts.insert(0, "Collect (%d)" % n)
		if Trade.current_ship().is_empty():
			acts.erase("Ships")
			var na := Trade.next_arrival()
			if not na.is_empty():
				p["off"].append("No ship in — next in ~%d day%s" % [maxi(1, int(na["days"])), "" if int(na["days"]) == 1 else "s"])
	p["actions"] = acts.slice(0, MAX_ACTIONS)
	if not (v["hours"] as Array).is_empty():
		p["status"] = Venues.status_text(vid).to_lower()
	return p


static func _shop_counter() -> Dictionary:
	var p := _p("Your shop counter")
	var n := Shop.waiting().size()
	p["actions"] = ["Serve (%d waiting)" % n] if n > 0 else ["Stock & prices"]
	if n == 0:
		p["actions"].append("Ledger")
	return p


# ------------------------------------------------------------------ stations
static func _station(sid: String) -> Dictionary:
	if sid == Contracts.BENCH:
		return Contracts.prompt()   # The Living Realm: the Project Bench (major contracts)
	var st := DB.station(sid)
	var p := _p(str(st.get("name", sid)))
	# iteration 012: an apprentice at this station says so (the smith still takes it; they step aside)
	var ap := ApprenticeActors.station_prompt(sid, "")
	if ap != "":
		p["note"] = ap.trim_prefix(" — ")
	var why := Crafting.station_locked_reason(sid)
	if why != "":
		p["actions"] = ["Details"]
		p["off"] = ["Locked — " + why]
		return p
	# S2 (OBS-12): the skill check this station runs, named before the smith commits ("check: precision ring")
	p["check"] = StationPanel.check_name(sid)
	p["status"] = "check: " + str(p["check"])
	var job := Crafting.job()
	if not job.is_empty():
		if bool(job.get("awaiting_dice", false)):
			p["actions"] = ["Roll the dice"]
		elif Crafting.current_station() == sid:
			p["actions"] = [str(Crafting.current_op().get("op", "Work")).capitalize() + " (next step)"]
		else:
			p["actions"] = ["Current work"]
			var fh := Smithy.floor_hint(Crafting.current_station())   # The Living Realm: "upstairs in the Loft"
			p["off"] = ["Next step: %s at %s%s" % [str(Crafting.current_op().get("op", "")).to_lower(), Smithy.station_ref(Crafting.current_station()),
				(" (" + fh + ")") if fh != "" else ""]]
		return p
	var ready := _ready_count(sid)
	var acts: Array = []
	if ready > 0:
		acts.append("Craft (%d ready)" % ready)
	else:
		acts.append("Designs")
		p["off"].append("Nothing ready — materials missing")
	match sid:
		"grinding_wheel":
			acts.append("Sharpen")
			var reps := Shop.waiting().filter(func(c): return str(c.get("want", "")) == "repair").size()
			if reps > 0:
				p["off"].append("Repair — %d waiting at your counter" % reps)
		"anvil":
			acts.append("Reforge")
		"rune_engraving_stand":
			acts.append("Socket runes")
		"infusion_rack":
			acts.append("Treat")
	acts.append("Practise")
	p["actions"] = acts.slice(0, MAX_ACTIONS)
	return p


## Recipes that could be started at this station right now (learned, stations free of locks, materials held).
static func _ready_count(sid: String) -> int:
	var n := 0
	for r in Crafting.recipes_for_station(sid):
		var rid := str(r["id"])
		if Crafting.recipe_locked_reason(rid) == "" and Crafting.missing_inputs(rid).is_empty():
			n += 1
	return n


# ------------------------------------------------------------------ people
static func _npc(npc: String, area: String) -> Dictionary:
	var p := _p(Talk.npc_name(npc))
	if npc.begins_with("app_"):
		p["actions"] = ["Talk"]
		return p
	var na := npc_actions(npc, area)
	p["actions"] = na["actions"]
	p["off"] = na["off"]
	return p


## Short verbs for what a conversation offers now, and greyed "Verb — reason" for expected-but-unavailable ones.
static func npc_actions(npc: String, area := "village") -> Dictionary:
	var acts: Array = []
	var off: Array = []
	for o in Talk.options(npc, area):
		var verb := str(VERBS.get(str(o["id"]), ""))
		if verb == "":
			continue
		var why := str(o.get("disabled", ""))
		if why != "":
			var line := "%s — %s" % [verb, why]
			if off.size() < MAX_OFF and not off.has(line) and not acts.has(verb):
				off.append(line)
			continue
		if not acts.has(verb) and acts.size() < MAX_ACTIONS:
			acts.append(verb)
	if acts.is_empty():
		acts.append("Talk")
	# "Talk" leads unless something more pressing (a delivery, a customer) comes first
	return {"actions": acts, "off": off}


# ------------------------------------------------------------------ text
## The main line as the HUD shows it.
static func line(p: Dictionary, key := "E") -> String:
	if str(p.get("title", "")) == "":
		return ("[%s]  %s" % [key, str(p.get("text", ""))]) if str(p.get("text", "")) != "" else ""
	var acts: Array = p.get("actions", [])
	var s := str(p["title"])
	if not acts.is_empty():
		s += " — [%s] %s" % [key, " · ".join(acts)]
	if str(p.get("status", "")) != "":
		s += (" (%s)" % str(p["status"])) if not acts.is_empty() else (" — " + str(p["status"]))
	return s


## The quieter second line: who is using it (apprentices) and what cannot be done now, with why.
static func sub(p: Dictionary) -> String:
	var parts: Array = []
	if str(p.get("note", "")) != "":
		parts.append(str(p["note"]))
	parts.append_array(p.get("off", []))
	return "   ·   ".join(parts)
