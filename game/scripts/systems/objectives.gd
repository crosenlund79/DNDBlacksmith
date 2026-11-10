## Objectives — the guided first-day loop shown in the HUD.
## EN: A light, skippable tutorial chain that walks the player through every major system once.
##     S2: keys in the lines come from the real bindings ({action} → Settings.key_label); "serve_mira" says what the
##     player can do right now (Aldric's commission arrives at 15:00; delivering it never depends on Mira's purse: her
##     share comes from what she has, the recorded village subsidy pays the rest — A2, canon D14); and an objective
##     that can no longer happen (her commission lapsed) closes as missed so the chain never waits for ever.
##     State: Game.state["objectives"] = {done: [ids], current: id, missed: [ids] (S2, created lazily)}.
## DA: En let, valgfri vejledningskæde, der fører spilleren gennem alle hovedsystemer én gang.
class_name Objectives
extends RefCounted

const ORDER := [
	["talk_borin", "Speak with Borin in the workshop"],
	["send_borin", "Open Hirelings [{panel_hirelings}]: assign Borin to Mining and send him to Ironroot Mine"],
	["select_recipe", "At the Anvil, choose the Iron Longsword recipe"],
	["craft_sword", "Work the stations in order — forge, anvil, quench, grind — then roll the dice"],
	["serve_mira", "Mira needs gear before the Barrow Fields — sell it to her or deliver her commission (Commissions [{panel_orders}])"],
	["visit_inn", "Visit the Tipsy Wyvern next door and talk to an adventurer"],
	["watch_depart", "Adventurers leave at dawn — sleep in your bed and watch them go"],
	["open_bag", "Borin is back! Open his bag in the workshop"],
	["save_game", "Save your game ({cancel} → Save, or {quick_save} to quick-save)"],
]

static var _wired := false


static func init() -> void:
	Game.state["objectives"] = {"done": [], "current": ORDER[0][0]}


static func text() -> String:
	var cur: String = Game.state.get("objectives", {}).get("current", "")
	for o in ORDER:
		if o[0] == cur:
			return _keys(_live(cur, str(o[1])))
	return ""


## {action} placeholders → the keys really bound to them.
static func _keys(t: String) -> String:
	for action in Settings.DEFAULT_KEYS:
		t = t.replace("{%s}" % action, Settings.key_label(str(action)))
	return t


## S2: the line for an objective as things stand (the opening commission for Mira, its state and who pays).
static func _live(id: String, base: String) -> String:
	if id != "serve_mira":
		return base
	var o := mira_order()
	if not o.is_empty():
		return "Deliver Mira's commission (Commissions [{panel_orders}]) by day %d — she pays her share from her purse, the village subsidy the rest. Or sell her a piece she can afford." % int(o.get("deadline", Game.day()))
	if not Game.has_flag("aldric_asked"):
		return "Mira needs gear before the Barrow Fields — her father Aldric comes by at 15:00 to commission it. Or sell her a piece she can afford."
	return base


## Mira's open commission ({} when none).
static func mira_order() -> Dictionary:
	if not Game.state.has("orders"):
		return {}
	for o in Shop.orders():
		if str(o.get("npc", "")) == "mira" and str(o.get("status", "")) == "open":
			return o
	return {}


static func is_done(id: String) -> bool:
	return Game.state.get("objectives", {}).get("done", []).has(id)


## S2: closed because it could no longer happen (still counted in done, so the chain moves on).
static func was_missed(id: String) -> bool:
	return Game.state.get("objectives", {}).get("missed", []).has(id)


static func complete(id: String) -> void:
	var ob: Dictionary = Game.state.get("objectives", {})
	if ob.is_empty() or ob["done"].has(id):
		return
	ob["done"].append(id)
	if ob["done"].has(ob["current"]):
		_advance()
	Events.objective_changed.emit(text())


## S2: an objective that can no longer happen closes as missed (with an honest line) and the chain moves on.
static func miss(id: String, why: String) -> void:
	var ob: Dictionary = Game.state.get("objectives", {})
	if ob.is_empty() or ob["done"].has(id):
		return
	if not ob.has("missed"):
		ob["missed"] = []
	(ob["missed"] as Array).append(id)
	if why != "":
		Events.toast.emit(why, "info")
	complete(id)


static func set_current(id: String) -> void:
	var ob: Dictionary = Game.state.get("objectives", {})
	if ob.is_empty() or ob["done"].has(id):
		return
	ob["current"] = id
	Events.objective_changed.emit(text())


static func _advance() -> void:
	var ob: Dictionary = Game.state["objectives"]
	for o in ORDER:
		if not ob["done"].has(o[0]):
			ob["current"] = o[0]
			return
	ob["current"] = ""


static func on_crafted(it: Dictionary) -> void:
	if Items.slot(it) == "weapon":
		complete("craft_sword")


static func on_sold(npc: String, _it: Dictionary) -> void:
	if bool(_it.get("dev", false)):
		return   # a developer-tool piece never completes an objective
	Tutorial.on_served(npc)   # S2: serving someone in person completes the selling step even when the subsidy paid
	if npc == "mira":
		complete("serve_mira")


## S2: connects the checks below to the Events bus once (Tutorial.wire calls it with the HUD).
static func wire() -> void:
	if _wired:
		return
	_wired = true
	Events.orders_changed.connect(check)
	Events.hour_passed.connect(func(_d, _h): check())
	Events.game_loaded.connect(check)


## S2: "serve_mira" can no longer happen once Aldric has asked and no commission for her is open (it lapsed unserved,
## or could not be placed) — not serving her is the player's choice and the world keeps its own consequences (a missed
## commission is remembered: Shop.expire_orders), so the guide says so and moves on instead of asking for ever.
## Borin's steps likewise: if he died (or left), nobody is left to talk to, send or bring a bag; and once his bag is gone
## without being opened in the workshop (and he is not away again), "open_bag" cannot happen either.
static func check() -> void:
	var ob: Dictionary = Game.state.get("objectives", {})
	if ob.is_empty():
		return
	var done: Array = ob.get("done", [])
	if not done.has("serve_mira") and Game.has_flag("aldric_asked") and mira_order().is_empty():
		# a delivered commission is served (Objectives.on_sold follows the delivery); only a lapsed or missing one is missed
		var delivered := Shop.orders().any(func(o): return str(o.get("npc", "")) == "mira" and str(o.get("status", "")) == "done")
		if not delivered:
			miss("serve_mira", "Mira's commission is no longer open — the first-day guide moves on.")
	if not Game.state.has("hirelings"):
		return
	var b := Hire.get_h("borin")
	var gone := b.is_empty() or str(b.get("status", "")) == "dead"
	if gone:
		for id in ["talk_borin", "send_borin"]:
			if not done.has(id):
				miss(id, "")
	if not done.has("open_bag"):
		var bag := false
		for c in Game.state.get("returns", []):
			if str(c.get("from", "")).begins_with("Borin"):
				bag = true
		if not bag and (gone or (Game.has_flag("borin_first_bag") and str(b.get("status", "")) != "away")):
			miss("open_bag", "Borin's bag is no longer waiting in the workshop — the first-day guide moves on.")
