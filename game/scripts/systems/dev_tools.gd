## DevTools — the developer catalogue behind F10: search every item definition, spawn items into the stores
## with quantity / rarity / craftsmanship, and add money. Testing only.
## EN: Every spawned item is marked it["dev"] = true (stacks too; dev stacks never merge with real ones).
##     Spawned equipment gets a real uid and provenance: maker "Developer tools", no mark, owner the smith —
##     and never counts for anything earned: Hall of Fame / Epic / names (Recognition, ItemStory), objectives,
##     the skill tree's "items seen" and knowledge flags, the encyclopedia, apprentices' fame.
##     Money is logged in the ledger as "Developer tools" (category "dev", left out of the accounts).
## DA: Udviklerkatalog (F10): søg alle genstande, læg dem i lageret, tilføj penge — kun til test.
class_name DevTools
extends RefCounted

const MAKER_ID := "dev"
const MAKER_NAME := "Developer tools"
const MONEY_PRESETS := [100, 1000, 10000]
## Type filter: [label, [def types]] ([] = all).
const FILTERS := [
	["All items", []], ["Weapons", ["weapon"]], ["Armour & shields", ["armor_metal", "armor_leather", "armor_cloth", "shield", "helmet", "cloak"]],
	["Hands, feet & belts", ["gloves", "boots", "belt"]], ["Rings & amulets", ["ring", "amulet"]], ["Materials", ["material"]],
	["Alchemy", ["potion"]], ["Runestones", ["runestone"]], ["Relics & curios", ["relic", "curio", "container"]], ["Companions", ["companion"]],
]
const RARITY_CHOICES := ["common", "magic", "rare", "legendary"]


static func is_dev(it: Dictionary) -> bool:
	return bool(it.get("dev", false))


## Item definitions matching a query (name, id or type; "" = all) and a type filter index, sorted by name.
static func search(query: String, filter := 0) -> Array:
	var q := query.strip_edges().to_lower()
	var types: Array = FILTERS[clampi(filter, 0, FILTERS.size() - 1)][1]
	var out := []
	for d in DB.items.values():
		var t := str(d.get("type", ""))
		if not types.is_empty() and not types.has(t):
			continue
		if q != "" and not (str(d["id"]).to_lower().contains(q) or str(d.get("name", "")).to_lower().contains(q) or t.contains(q)
				or Items.type_label({"def": str(d["id"])}).to_lower().contains(q)):
			continue
		out.append(d)
	out.sort_custom(func(a, b): return str(a.get("name", "")).naturalnocasecmp_to(str(b.get("name", ""))) < 0)
	return out


static func is_equipment_def(def_id: String) -> bool:
	return Items.is_equipment({"def": def_id})


## Does this definition take a craftsmanship (equipment, potions, runestones)?
static func has_quality(def_id: String) -> bool:
	return is_equipment_def(def_id) or str(DB.item(def_id).get("type", "")) in ["potion", "runestone"]


## Spawns `qty` of an item into the smith's stores. rarity: "" = common (unique/set pieces keep their own);
## quality < 0 = 90%. Returns the spawned instances (one per piece; one stack for stackables).
static func spawn(def_id: String, qty := 1, rarity := "", quality := -1.0) -> Array:
	var d := DB.item(def_id)
	if d.is_empty() or qty <= 0:
		return []
	var q := quality if quality >= 0.0 else 90.0
	var out := []
	var opts := {"quality": q, "crafted_by": MAKER_NAME}
	if is_equipment_def(def_id) and rarity in RARITY_CHOICES:
		opts["rarity"] = rarity
	if bool(d.get("stack", false)):
		opts["qty"] = qty
		var st := Items.make(def_id, opts)
		st["dev"] = true
		Game.add_item(st, false)
		out.append(st)
	else:
		for i in qty:
			var it := Items.make(def_id, opts)
			if it.is_empty():
				continue
			it["dev"] = true
			if Items.is_equipment(it):
				Provenance.set_maker(it, MAKER_ID, MAKER_NAME, "unknown", "the developer tools")
				Provenance.transfer(it, Provenance.SMITH_ID, "received", "", "%s was spawned by the developer tools." % Items.display_name(it))
			Game.add_item(it, false)
			out.append(it)
	Events.inventory_changed.emit()
	if not out.is_empty():
		Events.toast.emit("Developer tools: %s ×%d added to your stores." % [str(d.get("name", def_id)), qty], "info")
	return out


## Adds (or, negative, removes) money; logged in the ledger as "Developer tools".
static func add_money(amount: int) -> void:
	if amount == 0:
		return
	Game.add_gold(amount, "dev", MAKER_NAME, "dev")
	Events.toast.emit("Developer tools: %+d gold (now %d g)." % [amount, Game.gold()], "info")
