## Tutorial — a guided first game: short steps that complete when the player actually does the thing.
## EN: Sits beside Objectives (which tells the story of the first days); this teaches the controls
##     and systems. Steps listen to Events signals (wired once by wire()); any step can be completed
##     out of order, the card shows the first unfinished one. Skippable, and re-enabled from Help.
##     State: Game.state["tutorial"] = {on: bool, done: [step ids]} (created lazily: on for a fresh game).
## DA: En guidet introduktion; trinene fuldføres, når spilleren faktisk gør tingen.
class_name Tutorial
extends RefCounted

## id, title, text, events that complete it
const STEPS := [
	{"id": "move", "title": "Find your feet", "text": "Walk with W A S D or the arrow keys. Hold Shift to hurry.", "on": ["moved"]},
	{"id": "interact", "title": "Lend a hand", "text": "Walk up to a person or a workstation and press E (or Space) when its name appears.", "on": ["panel:dialogue", "panel:station", "panel:shop", "panel:notice", "panel:loot", "panel:sleep"]},
	{"id": "craft", "title": "Work the metal", "text": "At a station, choose a recipe, then play its precision checks: press E as the needle crosses the gilt zone.", "on": ["station_worked"]},
	{"id": "dice", "title": "Roll for fortune", "text": "Finish every step of the recipe, then roll the dice. Craftsmanship and the fortune die decide the rarity.", "on": ["item_crafted"]},
	{"id": "customer", "title": "Serve a customer", "text": "Customers sit outside the shop door (speech marks on the minimap). Talk to them to sell, repair or deliver a commission.", "on": ["sale"]},
	{"id": "skills", "title": "Know your craft", "text": "Open the skill tree with K or from the toolbar; U (or a right-click on the button) shows your skill levels.", "on": ["panel:skills", "panel:skilltree"]},
	{"id": "hirelings", "title": "Put your people to work", "text": "Open Hirelings (H) and set what Borin works at — or send him on an expedition.", "on": ["hireling_work"]},
	{"id": "adventurers", "title": "Meet the adventurers", "text": "Adventurers buy your gear and risk their lives with it. See them with J, or the Most Wanted board with B.", "on": ["panel:adventurers", "panel:wanted", "panel:dossier", "adventurer_talk"]},
	{"id": "progress", "title": "Grow the forge", "text": "Plan your future: spend points in the skill tree, or open Workshop to buy and furnish rooms.", "on": ["panel:property"]},
]

static var _wired := false
static var _moved := 0.0


static func ensure() -> Dictionary:
	if Game.state.is_empty():
		return {}
	if not Game.state.has("tutorial"):
		# a fresh game starts with the tutorial; an old save (already under way) does not
		var fresh := Game.day() <= 1 and int(Game.state.get("stats", {}).get("crafted", 0)) == 0
		Game.state["tutorial"] = {"on": fresh, "done": []}
	return Game.state["tutorial"]


static func enabled() -> bool:
	return bool(ensure().get("on", false))


static func set_enabled(on: bool) -> void:
	ensure()["on"] = on


## Turns the tutorial back on from the start (Help → "Restart the tutorial").
static func restart() -> void:
	var t := ensure()
	t["on"] = true
	t["done"] = []


static func is_done(id: String) -> bool:
	return (ensure().get("done", []) as Array).has(id)


## The first unfinished step ({} when finished or switched off).
static func current() -> Dictionary:
	if not enabled():
		return {}
	for s in STEPS:
		if not is_done(s["id"]):
			return s
	return {}


static func index_of(id: String) -> int:
	for i in STEPS.size():
		if STEPS[i]["id"] == id:
			return i
	return -1


static func complete(id: String) -> void:
	var t := ensure()
	if t.is_empty() or (t["done"] as Array).has(id):
		return
	(t["done"] as Array).append(id)
	if bool(t.get("on", false)):
		Events.toast.emit("Tutorial: %s — done." % _title(id), "good")
		if current().is_empty():
			t["on"] = false
			Events.toast.emit("Tutorial complete. Help (F1) has the full reference guide.", "good")


static func skip_step() -> void:
	var c := current()
	if not c.is_empty():
		(ensure()["done"] as Array).append(c["id"])
		if current().is_empty():
			ensure()["on"] = false


static func _title(id: String) -> String:
	var i := index_of(id)
	return str(STEPS[i]["title"]) if i >= 0 else id


## Feeds an event key ("moved", "panel:<id>", "station_worked", "item_crafted", "sale",
## "hireling_work", "adventurer_talk") to the steps. Steps complete whether or not they are current.
static func notify(ev: String) -> void:
	if Game.state.is_empty():
		return
	var t := ensure()
	for s in STEPS:
		if (s["on"] as Array).has(ev):
			complete(s["id"])
	# the skill tree also counts for "progress" once the skills step is behind you
	if ev == "panel:skilltree" and (t["done"] as Array).has("skills") and index_of(str(current().get("id", ""))) >= index_of("progress"):
		complete("progress")


## Called by the HUD a few times a second with the distance the player walked since the last call.
static func on_moved(dist: float) -> void:
	if is_done("move") or Game.state.is_empty():
		return
	_moved += dist
	if _moved >= 260.0:
		notify("moved")


## Connects to the Events bus once (safe to call repeatedly).
static func wire() -> void:
	if _wired:
		return
	_wired = true
	Events.open_panel.connect(_on_panel)
	Events.station_worked.connect(func(_s, _q): notify("station_worked"))
	Events.item_crafted.connect(func(_it): notify("item_crafted"))
	Events.gold_changed.connect(_on_gold)
	Events.hireling_departed.connect(func(_id, _ex): notify("hireling_work"))
	Events.hirelings_changed.connect(_on_hirelings)


static func _on_panel(id: String, args: Dictionary) -> void:
	if id == "prompt":
		return
	notify("panel:" + id)
	if id == "dialogue" and not Adv.get_a(str(args.get("npc", ""))).is_empty():
		notify("adventurer_talk")


static func _on_gold(_g: int) -> void:
	var l: Array = Game.state.get("ledger", [])
	if not l.is_empty() and str(l[-1].get("cat", "")) in ["sales", "repairs", "commissions"] and int(l[-1].get("amount", 0)) > 0:
		notify("sale")


## Allocation changes count while the Hirelings ledger is open (the daily wage tick does not).
static func _on_hirelings() -> void:
	if UIRoot.instance and is_instance_valid(UIRoot.instance.current) and UIRoot.instance.current is HirelingsPanel:
		notify("hireling_work")
