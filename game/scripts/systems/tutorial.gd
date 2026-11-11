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
	{"id": "move", "title": "Find your feet", "text": "Walk with W A S D or the arrow keys. Hold {run} to hurry.", "on": ["moved"]},
	{"id": "interact", "title": "Lend a hand", "text": "Walk up to a person or a workstation and press {interact} (or Space) when its name appears.", "on": ["panel:dialogue", "panel:station", "panel:shop", "panel:notice", "panel:loot", "panel:sleep"]},
	{"id": "craft", "title": "Work the metal", "text": "At a station, choose a Design, then play its precision checks: press {interact} as the needle crosses the gilt zone.", "on": ["station_worked"]},
	{"id": "dice", "title": "Roll for fortune", "text": "Finish every step of the Design, then roll the dice. Craftsmanship and the fortune die decide the rarity.", "on": ["item_crafted"]},
	{"id": "customer", "title": "Serve a customer", "text": "Customers sit outside the shop door (speech marks on the minimap). Talk to them to sell, repair or deliver a commission.", "on": ["sale"]},
	{"id": "skills", "title": "Know your craft", "text": "Open the Skill Tree with {panel_skills} (or its toolbar button); {panel_skill_levels} (or a right-click on that button) shows your skill levels.", "on": ["panel:skills", "panel:skilltree"]},
	{"id": "hirelings", "title": "Put your people to work", "text": "Open Hirelings ({panel_hirelings}) and set what Borin works at — or send him on an expedition.", "on": ["hireling_work"]},
	{"id": "adventurers", "title": "Meet the adventurers", "text": "Adventurers buy your gear and risk their lives with it. See them with {panel_adventurers}, or the Most Wanted board with {panel_wanted}.", "on": ["panel:adventurers", "panel:wanted", "panel:dossier", "adventurer_talk"]},
	{"id": "progress", "title": "Grow the forge", "text": "Plan your future: spend points in the Skill Tree, or open the Workshop ({panel_property}) to buy and furnish rooms.", "on": ["panel:property"]},
]


## S2: a step's text with its {action} placeholders replaced by the real keys (Settings), so the tutorial can never
## name a key that does something else.
static func step_text(s: Dictionary) -> String:
	var t := str(s.get("text", ""))
	for action in Settings.DEFAULT_KEYS:
		t = t.replace("{%s}" % action, Settings.key_label(str(action)))
	return t

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
	# S2: while the steward walks the smith (autopilot) the player is not moving him — that is not the player's step
	if is_done("move") or Game.state.is_empty() or Steward.smith_away():
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
	Objectives.wire()   # S2: the opening objectives move on when one can no longer happen (Mira's lapsed commission)


static func _on_panel(id: String, args: Dictionary) -> void:
	if id == "prompt":
		return
	notify("panel:" + id)
	if id == "dialogue" and not Adv.get_a(str(args.get("npc", ""))).is_empty():
		notify("adventurer_talk")


## Panels in which the smith serves a customer himself (the counter, a conversation, a consultation, the orders).
const COUNTER_PANELS := ["shop", "dialogue", "consult", "orders"]
## Tests: true/false forces serving_at_counter(); null asks the UI.
static var serving_override: Variant = null


## Income counts as "serving a customer" only when the smith earned it himself at the counter: Borin's horseshoes, an
## adventurer buying a draught or a piece off the display by themselves, an apprentice's repair or the steward's sales
## while the smith is away write the same ledger categories but teach the player nothing about selling (A2 observation
## 1: those background sales used to tick the step off before any customer had sat down).
## S2 (BUG-050): the counter panel alone is not enough — Borin's hourly "sales" line (payer "market") arriving while a
## conversation or the counter is open used to tick the step. The A2 ledger names the payer (`party`): only a payment by
## the person the smith is serving there and then counts (party_served).
static func _on_gold(_g: int) -> void:
	var l: Array = Game.state.get("ledger", [])
	if not l.is_empty() and str(l[-1].get("cat", "")) in ["sales", "repairs", "commissions"] and int(l[-1].get("amount", 0)) > 0 \
			and serving_at_counter() and party_served(str(l[-1].get("party", ""))):
		notify("sale")


## S2: the smith served `npc` in person — a sale or a delivered commission (Objectives.on_sold). A commission whose
## customer's purse was empty is paid entirely by the recorded village subsidy (A2, canon D14), so no "commissions"
## line in their name reaches _on_gold; the service itself still counts (Mira Pell's opening commission).
static func on_served(npc: String) -> void:
	if not Game.state.is_empty() and serving_at_counter() and party_served(npc):
		notify("sale")


## Tests: a person id forces party_served() to "the smith is serving this person" ("" = serving_override, else the UI).
static var served_override := ""


## Is `party` (a ledger payer) the person the smith is serving at the counter right now: seated at the counter, or the
## one the open conversation, consultation or commission board is about? The market (Borin's horseshoes), the village
## subsidy, a collector or a farm are never "a customer at the counter".
static func party_served(party: String) -> bool:
	if party == "" or (Adv.get_a(party).is_empty() and DB.character(party).is_empty()):
		return false
	if served_override != "":
		return party == served_override
	if serving_override != null:
		return bool(serving_override)   # tests that force "a counter panel is open" serve whoever pays in person
	var c := Shop.customer(party)
	if not c.is_empty() and bool(c.get("present", true)):
		return true
	var ui := UIRoot.instance
	if not is_instance_valid(ui) or not is_instance_valid(ui.current):
		return false
	var p: Control = ui.current
	if p is DialoguePanel:
		return (p as DialoguePanel).npc == party
	if p is ConsultPanel:
		return (p as ConsultPanel).npc == party
	if p is OrdersPanel:
		return Shop.orders().any(func(o): return str(o.get("npc", "")) == party)
	return false


## Is the smith serving someone in person right now (a counter panel open, and not away with the steward in charge)?
static func serving_at_counter() -> bool:
	if serving_override != null:
		return bool(serving_override)
	if Steward.smith_away():
		return false
	var ui := UIRoot.instance
	return is_instance_valid(ui) and is_instance_valid(ui.current) and ui.current_id in COUNTER_PANELS


## The selling step's live status line, so the step stays useful until someone can actually be served:
## {state: "ready"|"coming"|"none"|"closed", text} ({} without a game). "ready" = a customer sits at the counter now.
static func customer_status() -> Dictionary:
	if Game.state.is_empty() or not Game.state.has("customers"):
		return {}
	var ready := []
	var coming := []
	for c in Shop.customers():
		if bool(c.get("present", true)):
			ready.append(Talk.npc_name(str(c["npc"])))
		else:
			coming.append(Talk.npc_name(str(c["npc"])))
	if not ready.is_empty():
		var who: String = str(ready[0]) if ready.size() == 1 else "%s and %d more" % [ready[0], ready.size() - 1]
		return {"state": "ready", "text": "%s %s waiting by the shop door — talk to them, or open the counter." % [who, "is" if ready.size() == 1 else "are"]}
	if not coming.is_empty():
		return {"state": "coming", "text": "%s is on the way to the shop — a bell rings when they sit down." % coming[0]}
	var h := Game.hour()
	if h < 9 or h >= 18:
		return {"state": "closed", "text": "The shop is closed — customers come from 9:00 to 18:00. Forge something to sell meanwhile."}
	return {"state": "none", "text": "Nobody is waiting yet. Keep working — customers drop by in opening hours, and a bell rings when one sits down."}


## Allocation changes count while the Hirelings ledger is open (the daily wage tick does not).
static func _on_hirelings() -> void:
	# is_instance_valid first: between leaving a game and the next one's HUD the old UIRoot is already freed
	if is_instance_valid(UIRoot.instance) and is_instance_valid(UIRoot.instance.current) and UIRoot.instance.current is HirelingsPanel:
		notify("hireling_work")
