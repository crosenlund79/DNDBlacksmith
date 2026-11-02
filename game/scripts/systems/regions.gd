## Regions — what the workshop knows about the land around Brindlewick, and what it can do there.
## EN: Scouting knowledge per destination (built by travelling hands and shared rumours) lowers the
##     danger for everyone who goes there, hirelings and adventurers alike. Some regions reveal
##     suppliers when first scouted; trade runs then buy their materials and sell the workshop's
##     trade goods (potions, oils, coatings, spare materials marked for trade). Relics brought home
##     unidentified are studied — by the smith at the cleansing basin, or by a relic hunter during
##     work hours — and turn out to be ancient arms, rare components or forgotten recipes.
## DA: Spejderviden sænker faren for alle; første spejdertur finder leverandører; handelsture køber
##     materialer og sælger varer; uidentificerede relikvier undersøges og bliver til gamle våben,
##     sjældne komponenter eller glemte opskrifter.
class_name Regions
extends RefCounted

const SCOUT_MAX := 40.0


static func world() -> Dictionary:
	return Game.state["world"]


static func scouted(dest: String) -> float:
	return float(world().get("scouted", {}).get(dest, 0.0))


static func add_scouting(dest: String, pts: float, why := "") -> void:
	if not world().has("scouted"):
		world()["scouted"] = {}
	var before := scouted(dest)
	world()["scouted"][dest] = minf(SCOUT_MAX, before + pts)
	if knowledge_word(before) != knowledge_word(scouted(dest)):
		var d: Dictionary = DB.destinations.get(dest, {})
		Game.journal("%s: the way through %s is now %s%s." % [d.get("name", dest), d.get("name", dest), knowledge_word(scouted(dest)), (" (" + why + ")") if why != "" else ""])


static func knowledge_word(pts: float) -> String:
	if pts >= 30.0:
		return "well charted"
	if pts >= 15.0:
		return "scouted"
	if pts >= 5.0:
		return "partly known"
	return "unknown"


## Danger after scouting knowledge: up to 30% lower when well charted.
static func danger(dest: String) -> float:
	var d: Dictionary = DB.destinations.get(dest, {})
	return float(d.get("danger", 1)) * (1.0 - 0.3 * scouted(dest) / SCOUT_MAX)


## Called when a hireling or adventurer returns from a region.
static func on_trip(dest: String, travelling: int, success: bool) -> void:
	add_scouting(dest, (2.0 + travelling * 1.5) * (1.0 if success else 0.5))
	var d: Dictionary = DB.destinations.get(dest, {})
	var flag := str(d.get("discovers", ""))
	if flag != "" and not Game.has_flag(flag) and scouted(dest) >= 5.0:
		Game.set_flag(flag)
		var names := []
		for e in DB.suppliers.get(flag, []):
			names.append(DB.item(e[0]).get("name", e[0]))
		Game.journal("New supplier found on %s: %s." % [d.get("name", dest), ", ".join(names)])
		Events.toast.emit("A new supplier on %s — trade runs can now buy %s." % [d.get("name", dest), ", ".join(names.slice(0, 3))], "good")


# ------------------------------------------------------------------ trade runs
static func supply_list() -> Array:
	var out: Array = DB.suppliers.get("village", []).duplicate()
	for k in DB.suppliers:
		if k.begins_with("supplier_") and Game.has_flag(k):
			out.append_array(DB.suppliers[k])
	return out


## Items the workshop has set aside to sell on the road (non-equipment marked for trade).
static func trade_goods() -> Array:
	return Game.inventory().filter(func(it): return it.get("trade", false) and not Items.is_equipment(it))


## Resolves a trade run: spend the budget on the cheapest-per-need materials, sell trade goods.
## Returns {bought: [items], sold_gold: int, lines: [str]}.
static func run_trade(budget: int, travelling: int, want: Array) -> Dictionary:
	var discount := clampf(1.0 - 0.04 * travelling, 0.7, 1.0)
	var bought := []
	var lines := []
	var spend := budget
	var list := supply_list()
	if not want.is_empty():
		list = list.filter(func(e): return want.has(e[0]))
	list.shuffle()
	var guard := 0
	while spend > 0 and guard < 40 and not list.is_empty():
		guard += 1
		var e: Array = list[guard % list.size()]
		var price := maxi(1, int(round(float(e[1]) * discount)))
		if price > spend:
			if list.all(func(x): return int(round(float(x[1]) * discount)) > spend):
				break
			continue
		spend -= price
		var found := false
		for b in bought:
			if b["def"] == e[0]:
				b["qty"] = int(b["qty"]) + 1
				found = true
		if not found:
			bought.append(Items.make(e[0], {"qty": 1}))
	var sold := 0
	for it in trade_goods():
		var p := int(round(Items.value(it) * (0.85 + 0.05 * travelling)))
		sold += p
		lines.append("sold %s for %d g" % [Items.display_name(it), p])
		Game.inventory().erase(it)
	return {"bought": bought, "change": spend, "sold_gold": sold, "lines": lines}


# ------------------------------------------------------------------ relic study
static func is_unidentified(it: Dictionary) -> bool:
	return Items.def(it).get("tags", []).has("unidentified")


## Turns an unidentified relic into what it really is. quality = how well it was studied.
static func identify(uid: int, quality: float, by := "Brannoc") -> Dictionary:
	var it := Game.find_uid(uid)
	if it.is_empty() or not is_unidentified(it):
		return {}
	var table := "relic_reveal"
	var found := Loot.roll_table(table, (quality - 70.0) * 0.5)
	var res: Dictionary = found[0] if not found.is_empty() else Items.make("relic_coin")
	# what kind of relic it was nudges the outcome
	match str(it["def"]):
		"relic_unknown_arms":
			if randf() < 0.65:
				res = Loot.random_equipment("ancient", quality * 0.2)
		"relic_unknown_tablet":
			if randf() < 0.6 and not Game.has_flag("recipe_starsteel"):
				res = Items.make("recipe_scroll")
	if int(it.get("qty", 1)) > 1:
		it["qty"] = int(it["qty"]) - 1
	else:
		Game.inventory().erase(it)
	res["found_note"] = "Identified by %s from %s." % [by, it["name"]]
	Game.add_item(res, false)
	Game.journal("%s studied %s: it was %s." % [by, it["name"], Items.display_name(res)])
	Events.inventory_changed.emit()
	if res.get("rarity") == "legendary":
		Events.legendary_found.emit(res)
	return res


## Reading a forgotten recipe teaches it (sets its flag).
static func read_recipe(uid: int) -> String:
	var it := Game.find_uid(uid)
	if it.is_empty() or it["def"] != "recipe_scroll":
		return ""
	var unknown := []
	for r in DB.recipes.values():
		var f := str(r.get("requires_flag", ""))
		if f != "" and not Game.has_flag(f):
			unknown.append(r)
	Game.inventory().erase(it)
	Events.inventory_changed.emit()
	if unknown.is_empty():
		Game.add_gold(60, "sales", "Sold a duplicate recipe to a collector")
		return "You already know everything in these notes. A collector pays 60 g for them."
	var r: Dictionary = unknown.pick_random()
	Game.set_flag(str(r["requires_flag"]))
	Game.journal("Learned a forgotten recipe: %s." % r["name"])
	Audio.play("sfx/level_up")
	return "The notes describe the %s. You can make it now." % r["name"]
