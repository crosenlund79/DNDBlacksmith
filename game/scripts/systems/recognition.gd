## Recognition — the Blacksmith Hall of Fame and Epic distinction.
## EN: The Hall of Fame (Game.state["hall_of_fame"], created lazily) is a public board of brass plaques:
##     exceptional crafted pieces (very high craftsmanship, legendaries, masterworks), legendary
##     discoveries, important commissions and great deeds done with the smith's equipment.
##     It is filled from existing events: Crafting.finish calls on_crafted(); Chronicle.add hands every
##     entry to on_chronicle(); Expeditions._boss_down calls on_boss_down() with the killing weapon.
##     Epic is a historical distinction stored on an item (it["epic"] = {day, deed, adventurer, …}) that
##     a piece made by the smith earns when it takes part in a major accomplishment (the killing blow on
##     a boss, an adventurer's career milestone, the Unexpected Hero chain). It never changes the
##     rarity or the stats; it raises the smith's reputation and the item's value, and schedules a
##     ceremony in the village square (Ceremony).
## DA: Æreshallen (messingplader for mesterværker, fund, bestillinger og bedrifter) og Episk udmærkelse:
##     en historisk hæder på genstanden — ikke en sjældenhed — som giver omdømme, værdi og en ceremoni.
class_name Recognition
extends RefCounted

const CAP := 80
## Plaque categories: name, icon, and the filter they belong to.
const KINDS := {
	"craft": {"name": "Masterwork", "icon": "icons/star"},
	"discovery": {"name": "Discovery", "icon": "icons/gem_garnet"},
	"commission": {"name": "Commission", "icon": "icons/purse_gift"},
	"deed": {"name": "Great Deed", "icon": "icons/sword_iron"},
	"epic": {"name": "Epic", "icon": "icons/star"},
	"ceremony": {"name": "Ceremony", "icon": "icons/gold"},
	"named": {"name": "Named", "icon": "ui/story_named"},
}
const EPIC_COLOR := Color("#ff6f8e")          # rose-crimson accent on dark tooltips
const EPIC_COLOR_LIGHT := Color("#8a1f3c")    # the same on parchment
const EPIC_VALUE := 1.5                        # an Epic piece is worth half again as much
const EPIC_REP := 5.0
const SMITH := "Brannoc"


# ------------------------------------------------------------------ the board
static func entries() -> Array:
	if not Game.state.has("hall_of_fame"):
		Game.state["hall_of_fame"] = []
	return Game.state["hall_of_fame"]


static func has_key(key: String) -> bool:
	return key != "" and entries().any(func(e): return str(e.get("key", "")) == key)


## Adds a plaque (once per key). refs may hold "uid" (an item), "adv" (an adventurer), "def" (an item def).
static func record(kind: String, title: String, text: String, refs := {}, key := "") -> Dictionary:
	if has_key(key):
		return {}
	var e := {"id": "hof_%d" % Game.new_uid(), "key": key, "kind": kind, "day": Game.day(), "title": title, "text": text, "refs": refs}
	entries().append(e)
	while entries().size() > CAP:
		# the board keeps its finest: drop the oldest non-epic plaque first
		var drop := 0
		for i in entries().size():
			if str(entries()[i].get("kind", "")) != "epic":
				drop = i
				break
		entries().remove_at(drop)
	return e


static func of_kind(kind: String) -> Array:
	return entries().filter(func(e): return str(e.get("kind", "")) == kind)


## Plaques newest first, optionally of some kinds.
static func recent(n := 100, kinds := []) -> Array:
	var out := []
	for i in range(entries().size() - 1, -1, -1):
		var e: Dictionary = entries()[i]
		if kinds.is_empty() or kinds.has(e["kind"]):
			out.append(e)
			if out.size() >= n:
				break
	return out


static func made_by_smith(it: Dictionary) -> bool:
	return not it.is_empty() and str(it.get("crafted_by", "")).begins_with(SMITH)


# ------------------------------------------------------------------ hooks
## Crafting.finish: exceptional work goes on the board.
static func on_crafted(it: Dictionary) -> void:
	if it.is_empty():
		return
	var cr: Dictionary = it.get("craft", {})
	var q := float(it.get("quality", 0))
	var why := []
	if q >= 112.0:
		why.append("%d%% craftsmanship" % int(round(q)))
	if bool(cr.get("masterwork", false)):
		why.append("a masterwork")
	if str(it.get("rarity", "")) == "legendary":
		why.append("legendary")
	ItemStory.on_crafted(it)   # optional: a 120%+ masterwork is named by the smith at the anvil
	if why.is_empty():
		return
	record("craft", Items.display_name(it), "Forged at the Ironhand forge — %s." % ", ".join(PackedStringArray(why)),
		{"uid": int(it.get("uid", -1)), "def": str(it.get("def", "")), "rarity": str(it.get("rarity", "common")), "quality": q},
		"craft_%d" % int(it.get("uid", -1)))


## Chronicle.add hands every entry here (one-line hook). Only the kinds that matter are read.
static func on_chronicle(e: Dictionary) -> void:
	if Game.state.is_empty():
		return
	var refs: Dictionary = e.get("refs", {})
	var adv_id := str(refs.get("adv", ""))
	match str(e.get("kind", "")):
		"discovery", "relic":
			var it := Game.find_uid_anywhere(int(str(refs.get("item", "-1"))))
			var legendary: bool = it.is_empty() or str(it.get("rarity", "")) in ["legendary", "rare", "unique", "set"] or str(e.get("text", "")).to_lower().contains("legend")
			if legendary:
				record("discovery", "A find from afar", str(e["text"]), {"adv": adv_id, "uid": int(str(refs.get("item", "-1")))}, "disc_%d_%s" % [int(e.get("t", 0)), adv_id])
		"commission":
			var uid := int(refs.get("uid", -1))
			var o := {}
			for x in Shop.orders():
				if int(x.get("delivered_uid", -2)) == uid:
					o = x
			var it2 := Game.find_uid_anywhere(uid)
			var important: bool = int(o.get("reward", 0)) >= 150 or bool(o.get("bonus_met", false)) or str(it2.get("rarity", "")) in ["rare", "legendary"] \
				or int(o.get("tier", 1)) >= 2 or bool(o.get("multi", false))
			if important:
				record("commission", "Commission for %s" % Talk.npc_name(adv_id), str(e["text"]), {"adv": adv_id, "uid": uid}, "comm_%d" % uid)
		"legend":
			record("deed", "A blade with a name", str(e["text"]), {"adv": adv_id, "uid": int(str(refs.get("item", "-1")))}, "legend_%s" % str(refs.get("item", "")))
		"chain":
			if str(e.get("text", "")).begins_with("An unexpected hero"):
				var w := Game.find_uid_anywhere(int(str(refs.get("item", "-1"))))
				record("deed", "The Unexpected Hero", str(e["text"]), {"adv": adv_id, "uid": int(w.get("uid", -1))}, "hero_%s" % adv_id)
				grant_epic(w, "carried by the unexpected hero %s" % Talk.npc_name(adv_id), adv_id, "hero")
		"renown":
			var a := Adv.get_a(adv_id)
			if a.is_empty():
				return
			var title := Expeditions.renown_title(a)
			if title in ["Rising Blade", "Hero of Brindlewick", "Living Legend"]:
				var w2 := smith_gear_of(a)
				if not w2.is_empty():
					record("deed", "%s, %s" % [a["name"], title], "%s rose to be spoken of as %s, equipped by the Ironhand forge." % [a["name"], title], {"adv": adv_id, "uid": int(w2["uid"])}, "renown_%s_%s" % [adv_id, title])
					grant_epic(w2, "worn as %s became %s" % [a["name"], title], adv_id, "milestone")
		"levelup":
			var a2 := Adv.get_a(adv_id)
			if not a2.is_empty() and int(a2.get("level", 0)) == 10:
				var w3 := smith_gear_of(a2)
				if not w3.is_empty():
					record("deed", "%s reached level 10" % a2["name"], "%s reached the tenth level of their career with gear from the Ironhand forge." % a2["name"], {"adv": adv_id, "uid": int(w3["uid"])}, "lvl10_%s" % adv_id)
					grant_epic(w3, "carried by %s to the tenth level of their career" % a2["name"], adv_id, "milestone")


## Expeditions._boss_down: the killing blow on a boss, with the weapon that struck it.
static func on_boss_down(adv_id: String, weapon: Dictionary, boss_name: String, place: String) -> void:
	if not made_by_smith(weapon):
		return
	var a := Adv.get_a(adv_id)
	var who: String = a.get("name", Talk.npc_name(adv_id))
	record("deed", "%s slew %s" % [who, boss_name], "%s struck the killing blow on %s in %s with %s from the Ironhand forge." % [who, boss_name, place, weapon.get("name", "a blade")],
		{"adv": adv_id, "uid": int(weapon.get("uid", -1)), "boss": boss_name}, "boss_%s_%d" % [boss_name, Game.day()])
	grant_epic(weapon, "struck the killing blow on %s in %s" % [boss_name, place], adv_id, "boss")


## The adventurer's piece made by the smith that matters most: the weapon first, then anything.
static func smith_gear_of(a: Dictionary) -> Dictionary:
	var eq: Dictionary = a.get("equipment", {})
	if made_by_smith(eq.get("weapon", {})):
		return eq["weapon"]
	for s in eq:
		if made_by_smith(eq[s]):
			return eq[s]
	return {}


# ------------------------------------------------------------------ Epic distinction
static func is_epic(it: Dictionary) -> bool:
	return it.has("epic")


## Grants Epic recognition to a piece the smith made. Returns true the first time; later deeds are
## added to the item's epic record. Rarity and stats are left exactly as they were.
static func grant_epic(it: Dictionary, deed: String, adv_id := "", kind := "deed") -> bool:
	if not made_by_smith(it):
		return false
	var who := Talk.npc_name(adv_id) if adv_id != "" else ""
	if it.has("epic"):
		var ep: Dictionary = it["epic"]
		if not ep.has("deeds"):
			ep["deeds"] = []
		(ep["deeds"] as Array).append({"day": Game.day(), "deed": deed, "adventurer": adv_id})
		Lore.record("deed", "%s added another great deed: %s." % [Items.display_name(it), deed],
			{"items": [it], "actors": [adv_id] if adv_id != "" else [], "importance": 2})
		ItemStory.on_epic(it, deed)
		return false
	it["epic"] = {"day": Game.day(), "deed": deed, "adventurer": adv_id, "adventurer_name": who, "kind": kind, "deeds": []}
	# one shared record: the item's story, the adventurer's history and the news feed all point at this event
	Lore.record("epic", "%s earned Epic distinction: %s%s." % [Items.display_name(it), deed, (" (%s)" % who) if who != "" else ""],
		{"items": [it], "actors": [adv_id] if adv_id != "" else [], "importance": 3, "chronicle": true, "notable": true,
		"data": {"deed": deed}})
	ItemStory.on_epic(it, deed)
	Shop.rep_change(EPIC_REP, "a piece from the Ironhand forge did something epic.")
	record("epic", Items.display_name(it), "%s — %s." % [_cap(deed), who] if who != "" else _cap(deed) + ".",
		{"uid": int(it.get("uid", -1)), "adv": adv_id, "def": str(it.get("def", ""))}, "epic_%d" % int(it.get("uid", -1)))
	Events.toast.emit("EPIC — %s %s." % [Items.display_name(it), deed], "legendary")
	Ceremony.schedule(adv_id, int(it.get("uid", -1)), deed)
	Events.inventory_changed.emit()
	return true


static func _cap(t: String) -> String:
	return t.substr(0, 1).to_upper() + t.substr(1)


## One tooltip line for an Epic piece (or "").
static func epic_line(it: Dictionary) -> String:
	if not it.has("epic"):
		return ""
	var ep: Dictionary = it["epic"]
	var more := (ep.get("deeds", []) as Array).size()
	return "[color=#%s]✦ EPIC — %s%s (day %d)%s[/color]" % [EPIC_COLOR.to_html(false), str(ep.get("deed", "")),
		(", " + str(ep.get("adventurer_name", ""))) if str(ep.get("adventurer_name", "")) != "" else "", int(ep.get("day", 0)),
		(" · %d more deed%s" % [more, "" if more == 1 else "s"]) if more > 0 else ""]


# ------------------------------------------------------------------ customers at the board
## A waiting customer studies the Hall of Fame board: a remark and a small nudge. Returns the remark ("" = none).
static func customer_comment(npc: String) -> String:
	var es := recent(6)
	if es.is_empty():
		return ""
	var e: Dictionary = es.pick_random()
	var name := Talk.npc_name(npc)
	var line := ""
	match str(e.get("kind", "")):
		"epic":
			line = "\"%s — that's the one from the songs? You made that?\"" % e["title"]
		"deed":
			line = "\"%s... with your work in hand. Remarkable.\"" % e["title"]
		"craft":
			line = "\"%s. I'd save a year for something like that.\"" % e["title"]
		"commission":
			line = "\"You did that commission? Then you can do mine.\""
		_:
			line = "\"Quite the board you keep, smith.\""
	Social.change(npc, 1.5, 1.0, "", "", false)
	Shop.rep_change(0.3)
	Events.toast.emit("%s studies the Hall of Fame: %s" % [name, line], "info")
	return line
