## Objectives — the guided first-day loop shown in the HUD.
## EN: A light, skippable tutorial chain that walks the player through every major system once.
## DA: En let, valgfri vejledningskæde, der fører spilleren gennem alle hovedsystemer én gang.
class_name Objectives
extends RefCounted

const ORDER := [
	["talk_borin", "Speak with Borin in the workshop"],
	["send_borin", "Open Hirelings [H]: assign Borin to Mining and send him to Ironroot Mine"],
	["select_recipe", "At the Anvil, choose the Iron Longsword recipe"],
	["craft_sword", "Work the stations in order — forge, anvil, quench, grind — then roll the dice"],
	["serve_mira", "Mira needs gear before the Barrow Fields — sell or deliver it (Orders [O])"],
	["visit_inn", "Visit the Tipsy Wyvern next door and talk to an adventurer"],
	["watch_depart", "Adventurers leave at dawn — sleep in your bed and watch them go"],
	["open_bag", "Borin is back! Open his bag in the workshop"],
	["save_game", "Save your game (Esc → Save)"],
]


static func init() -> void:
	Game.state["objectives"] = {"done": [], "current": ORDER[0][0]}


static func text() -> String:
	var cur: String = Game.state.get("objectives", {}).get("current", "")
	for o in ORDER:
		if o[0] == cur:
			return o[1]
	return ""


static func is_done(id: String) -> bool:
	return Game.state.get("objectives", {}).get("done", []).has(id)


static func complete(id: String) -> void:
	var ob: Dictionary = Game.state.get("objectives", {})
	if ob.is_empty() or ob["done"].has(id):
		return
	ob["done"].append(id)
	if ob["done"].has(ob["current"]):
		_advance()
	Events.objective_changed.emit(text())


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
	if npc == "mira":
		complete("serve_mira")
