## Companions — creature companions as persistent item instances in an adventurer's "companion" slot.
## EN: A companion is an ordinary item instance (type "companion", slot "companion") made from a comp_* item def,
##     with a creature name ("Bramble the hound"), its keeper's history and the sprite id of its miniature
##     (def field `creature` → "creatures/<id>"). It lives in Adv equipment["companion"]; the Adventurer worker
##     applies its stats (attack, protection, scouting, heal, magic, carry, fire) on expeditions.
## DA: En dyreledsager er en almindelig genstand i eventyrerens "companion"-plads, med navn og historie.
##
## Public API (static):
##   make(def_id, quality := 88.0, name := "") -> Dictionary     defs() -> Array[String]   is_companion(it) -> bool
##   of(a) -> Dictionary (the adventurer's companion or {})        give(a, it, note := "") -> String ("" = ok)
##   creature_id(it) -> String   sprite(it) -> "creatures/<id>"   flying(it) -> bool   magical(def_id) -> bool
##   species(it) -> String       pet_name(it) -> String            stat_line(it) -> String
class_name Companions
extends RefCounted

const SLOT := "companion"
const STAT_NAMES := {"attack": "Attack", "protection": "Protection", "scouting": "Scouting", "heal": "Healing",
	"magic": "Magic", "carry": "Carry", "fire": "Fire"}


static func defs() -> Array:
	var out := []
	for id in DB.items:
		if str(DB.items[id].get("type", "")) == "companion":
			out.append(str(id))
	out.sort_custom(func(a, b): return int(DB.item(a).get("value", 0)) < int(DB.item(b).get("value", 0)))
	return out


static func is_companion(it: Dictionary) -> bool:
	return not it.is_empty() and str(Items.def(it).get("type", "")) == "companion"


static func magical(def_id: String) -> bool:
	return (DB.item(def_id).get("tags", []) as Array).has("magical")


static func species(it: Dictionary) -> String:
	return str(Items.def(it).get("species", "creature"))


static func creature_id(it: Dictionary) -> String:
	return str(Items.def(it).get("creature", it.get("def", "")))


static func sprite(it: Dictionary) -> String:
	return "creatures/" + creature_id(it)


static func flying(it: Dictionary) -> bool:
	return (Items.def(it).get("tags", []) as Array).has("flying")


static func pet_name(it: Dictionary) -> String:
	return str(it.get("creature_name", Items.def(it).get("name", "the creature")))


## A random name for a new creature of this kind (data/commerce.json creatures.names.<species>).
static func random_name(def_id: String) -> String:
	var sp := str(DB.item(def_id).get("species", ""))
	var pool: Array = Commerce.cfg().get("creatures", {}).get("names", {}).get(sp, [])
	if pool.is_empty():
		return "Scamp"
	return str(pool[randi() % pool.size()])


## A new companion instance: a named creature with a short history.
static func make(def_id: String, quality := 88.0, name := "") -> Dictionary:
	var it := Items.make(def_id, {"quality": quality})
	if it.is_empty():
		return {}
	var nm := name if name != "" else random_name(def_id)
	it["creature_name"] = nm
	it["name"] = "%s the %s" % [nm, str(DB.item(def_id).get("species", "creature"))]
	var keeper := str(DB.item(def_id).get("keeper", "hale_elder"))
	Items.add_history(it, "Raised at Hale Farm by %s." % DB.character(keeper).get("name", "the Hales"))
	return it


static func of(a: Dictionary) -> Dictionary:
	var e: Variant = a.get("equipment", {}).get(SLOT, {})
	return e if e is Dictionary else {}


## Puts a companion in the adventurer's companion slot. Refuses when they already keep one.
static func give(a: Dictionary, it: Dictionary, note := "") -> String:
	if a.is_empty() or not is_companion(it):
		return "That is no companion."
	if not of(a).is_empty():
		return "%s already keeps %s." % [a.get("name", "They"), pet_name(of(a))]
	if not a.has("equipment"):
		a["equipment"] = {}
	a["equipment"][SLOT] = it
	it["owner"] = str(a.get("id", ""))
	it.erase("for_sale")
	Items.add_history(it, note if note != "" else "Went to live with %s." % a.get("name", "an adventurer"))
	Events.adventurers_changed.emit()
	return ""


static func stat_line(it: Dictionary) -> String:
	var parts := []
	for k in STAT_NAMES:
		var v := Items.stat(it, k)
		if v != 0:
			parts.append("%s %+d" % [STAT_NAMES[k], v])
	return " · ".join(parts)


## Stats straight from the item def (for stock that is not an instance yet).
static func def_stat_line(def_id: String) -> String:
	var st: Dictionary = DB.item(def_id).get("stats", {})
	var parts := []
	for k in STAT_NAMES:
		if st.has(k):
			parts.append("%s %+d" % [STAT_NAMES[k], int(st[k])])
	return " · ".join(parts)
