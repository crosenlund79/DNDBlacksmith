## Venues — every place the smith deals with in Brindlewick, and the single source of their opening hours.
## EN: One registry for the shops, counters and services of the village: who keeps them, when they are open, what
##     kinds of goods they deal in (read from the real stock data, never a full inventory), whether pressing E at the
##     counter opens a purchasing screen, which panel and which quick-travel destination belong to them.
##     The keepers' daily routines in VillageWorld.spot_for / Commerce.spot_for read their hours from here, so the
##     map, the prompts and the world can never disagree. System APIs (Trade.buy_herbalist …) stay unrestricted;
##     only the counters in the world respect the hours.
## DA: Register over landsbyens butikker og tjenester med åbningstider (én kilde), varekategorier, betjening og
##     hurtigrejse-mål. Indehavernes skemaer i verdenen læser timerne herfra.
##
## Public API (static):
##   all() -> Array[Dictionary]                 ids() -> Array[String]           get_v(id) -> Dictionary ({} unknown)
##   in_hours(id, hour := -1) -> bool            is_open(id, hour := -1) -> bool  (hours + presence, e.g. caravan in camp)
##   present(id, hour := -1) -> bool             keeper_away(id, hour := -1) -> String ("" = at work; Aldric's delivery)
##   for_travel(dest_id) -> String               ICONS[id] -> quick-travel icon name (ui/qt_<icon>)
##   status_text(id, hour := -1) -> String       "Open until 19:00" | "Closed — opens 7:00" | "Away — next in ~3 days"
##   hours_text(id) -> String ("7:00–19:00")     closed_reason(id) -> String ("" when open)
##   categories(id) -> Array[String]             goods categories (from stock data) followed by services
##   stock_defs(id) -> Array[String]             item defs the venue can deal in (data, plus what is aboard now)
##   selling(def) -> Array[{id, name, note, price, sometimes, open}]   venues that can sell that item
##   selling_ids(def) -> Array[String]           category_of(def) -> String
##   venue_for_entity(kind, id) -> String        the venue of a world interactable ("" = none)
##   for_keeper(npc) -> String                   the venue an NPC keeps ("" = none)
##   travel_line(id) -> String                   one honest line for quick travel and the map card
##   card(id) -> Dictionary {id, name, type, status, open, hours, categories, interface, how, travel, keeper}
##   fmt_hour(h) -> String
class_name Venues
extends RefCounted

## Registry. hours [open, close) in whole hours (close 24 = midnight); [] = always open.
## presence: "" | "caravan" (only while the caravan is camped) | "own" (the smith's own forge)
## interface: pressing E at the counter opens a purchasing/trading screen (panel); otherwise you deal with the keeper.
## entity: [kind, id] of the counter interactable in the world.
const REGISTRY := [
	{"id": "forge", "name": "Ironhand Forge", "type": "Your forge & shop", "building": "smithy", "keeper": "",
		"spot": "smithy_counter_back", "hours": [], "presence": "own", "interface": true, "panel": "shop", "travel": "smithy",
		"services": ["Your stations", "Your shop counter", "Your stores"], "how": "Your own counter: sell to customers and keep the books."},
	{"id": "general_store", "name": "Pell's Provisions", "type": "General store", "building": "grocery", "keeper": "aldric",
		"spot": "grocery_behind", "hours": [7, 19], "interface": true, "panel": "store", "travel": "provisions",
		"entity": ["store", "general_store"], "stock": "trade:general_store", "services": ["Weekly provisions for the forge"],
		"how": "Aldric's counter: buy everyday materials. Fresh stock every morning."},
	{"id": "herbalist", "name": "Fennimore's Simples", "type": "Herbalist", "building": "herbalist", "keeper": "herbalist",
		"spot": "herbalist_counter", "hours": [8, 18], "interface": true, "panel": "herbalist", "travel": "herbalist",
		"entity": ["herbalist", "herbalist"], "stock": "trade:herbalist",
		"how": "Maud's counter: herbs, reagents and fibres. Fresh stock every morning."},
	{"id": "harbour", "name": "The Harbour", "type": "Harbourmaster — ships & imports", "building": "", "keeper": "harbourmaster",
		"spot": "harbour_quay", "hours": [6, 19], "interface": true, "panel": "harbour", "travel": "harbour",
		"entity": ["harbour", "harbour"], "stock": "harbour", "services": ["Special imports (2–5 days)", "Merchant ships every few days"],
		"how": "The harbourmaster's booth: buy from a docked ship or order a known material from abroad."},
	{"id": "caravan", "name": "The Brask Caravan", "type": "Travelling traders", "building": "", "keeper": "caravan_master",
		"spot": "caravan_camp", "hours": [7, 22], "presence": "caravan", "interface": true, "panel": "caravan", "travel": "caravan",
		"entity": ["caravan", "caravan"], "stock": "caravan", "services": ["Buys wanted goods at a premium"],
		"how": "The wagons in the caravan camp, for two days every week or so: rare wares from afar."},
	{"id": "pawn", "name": "The Three Brass Balls", "type": "Pawnbroker", "building": "pawnshop", "keeper": "pawnbroker",
		"spot": "pawn_counter", "hours": [8, 19], "interface": true, "panel": "pawn", "travel": "pawn",
		"entity": ["pawn", "pawn"], "stock": "pawn", "services": ["Pledges & loans", "Buys almost anything"],
		"how": "Silas Quell's counter: pledge, redeem, sell, or buy unclaimed curios."},
	{"id": "rival_smith", "name": "The Salt Anvil", "type": "Rival smith", "building": "rival_forge", "keeper": "rival_smith",
		"spot": "rival_smith_counter", "hours": [7, 18], "counter_from": 12, "interface": true, "panel": "rival_smith",
		"travel": "rival_smith", "entity": ["rival_smith", "rival_smith"], "stock": "rival",
		"how": "Maren's counter: sea-bronze arms and a few materials. At her forge in the morning, the counter after noon."},
	{"id": "creatures", "name": "The Hales' Menagerie", "type": "Creature dealers", "building": "hale_cottage", "keeper": "hale_elder",
		"spot": "hale_yard", "hours": [6, 18], "interface": true, "panel": "creatures", "travel": "creatures",
		"entity": ["creatures", "hale"], "stock": "creatures", "services": ["Commissions a creature for you"],
		"how": "The Hales' yard: companion beasts for you or for an adventurer."},
	{"id": "inn", "name": "The Tipsy Wyvern", "type": "Inn & tavern", "building": "inn", "keeper": "hilde",
		"spot": "inn_behind_bar", "hours": [6, 24], "interface": false, "panel": "", "travel": "inn",
		"services": ["Hot meals & ale", "Adventurers & gossip"],
		"how": "Talk to Hilde behind the bar for a meal or a round; adventurers gather at the tables."},
	{"id": "notice", "name": "Notice Board & Most Wanted", "type": "Village notices", "building": "", "keeper": "",
		"spot": "notice", "hours": [], "interface": true, "panel": "notice", "travel": "square", "entity": ["notice", "board"],
		"services": ["Applicants & apprentices", "Commissions", "Workshop upgrades", "Most Wanted"],
		"how": "The board in the square: hire help, take commissions, buy workshop upgrades."},
	{"id": "ironfront", "name": "Barnaby's (Ironfront)", "type": "Wargames parlour", "building": "barnaby_house", "keeper": "barnaby",
		"spot": "ironfront_host", "hours": [17, 23], "interface": false, "panel": "", "travel": "barnaby",
		"services": ["Ironfront matches", "Card decks"],
		"how": "Talk to Barnaby: his parlour by day, the Ironfront den below in the evening."},
]

## Map/quick-travel medallion icon per venue (ui/qt_<icon>).
const ICONS := {"forge": "smithy", "general_store": "market", "herbalist": "herbalist", "harbour": "harbour", "caravan": "caravan",
	"pawn": "pawn", "rival_smith": "rival", "creatures": "creatures", "inn": "inn", "notice": "square", "ironfront": "barnaby"}

## Goods categories (shown on the map card) in a stable order.
const CATEGORY_ORDER := ["Ore & metal", "Coal & fuel", "Hides & leather", "Thread & fibre", "Wood", "Herbs", "Reagents",
	"Gems", "Monster parts", "Potions", "Weapons", "Armour", "Jewellery", "Curios & relics", "Companion creatures", "Goods"]


static func all() -> Array:
	return REGISTRY


static func ids() -> Array:
	return REGISTRY.map(func(v): return str(v["id"]))


static func get_v(id: String) -> Dictionary:
	for v in REGISTRY:
		if v["id"] == id:
			return v
	return {}


static func for_keeper(npc: String) -> String:
	for v in REGISTRY:
		if str(v["keeper"]) == npc and npc != "":
			return str(v["id"])
	return ""


## The venue reached by a quick-travel destination ("" = none). The square leads to the notice board.
static func for_travel(dest_id: String) -> String:
	for v in REGISTRY:
		if str(v.get("travel", "")) == dest_id and dest_id != "":
			return str(v["id"])
	return ""


static func venue_for_entity(kind: String, id: String) -> String:
	for v in REGISTRY:
		var e: Array = v.get("entity", [])
		if e.size() == 2 and str(e[0]) == kind and str(e[1]) == id:
			return str(v["id"])
	return ""


static func _hour(h: int) -> int:
	return Game.hour() if h < 0 else h


## Within the opening hours (ignores presence rules such as the caravan being on the road).
static func in_hours(id: String, hour := -1) -> bool:
	var v := get_v(id)
	if v.is_empty():
		return false
	var hr: Array = v["hours"]
	if hr.is_empty():
		return true
	var h := _hour(hour)
	return h >= int(hr[0]) and h < int(hr[1])


static func present(id: String, hour := -1) -> bool:
	var v := get_v(id)
	match str(v.get("presence", "")):
		"caravan":
			return Commerce.caravan_present()
	return keeper_away(id, hour) == ""


## Why the keeper is away from an otherwise open counter ("" = not away). Aldric carries the weekly delivery
## to the forge between 9:00 and 17:00 (the world puts him at the smithy door for exactly that).
static func keeper_away(id: String, hour := -1) -> String:
	var h := _hour(hour)
	if id == "general_store" and not Game.state.is_empty() and bool(Game.state.get("world", {}).get("delivery_pending", false)) \
			and h >= 9 and h < 17 and in_hours(id, h):
		return "Aldric is at your forge with the weekly delivery"
	return ""


static func is_open(id: String, hour := -1) -> bool:
	return present(id, hour) and in_hours(id, hour)


static func fmt_hour(h: int) -> String:
	if h == 24 or h == 0:
		return "midnight"
	return "%d:00" % h


static func hours_text(id: String) -> String:
	var v := get_v(id)
	var hr: Array = v.get("hours", [])
	if hr.is_empty():
		return "Always open" if str(v.get("presence", "")) != "own" else "Yours, day and night"
	return "%s–%s" % [fmt_hour(int(hr[0])), fmt_hour(int(hr[1]))]


## Concise status: "Open until 19:00" | "Closed — opens 7:00" | "Away — next in ~3 days".
static func status_text(id: String, hour := -1) -> String:
	var v := get_v(id)
	if v.is_empty():
		return ""
	if str(v.get("presence", "")) == "own":
		return "Yours — always open"
	var away := keeper_away(id, hour)
	if away != "":
		return "Away — " + away
	if not present(id, hour):
		var n := Commerce.next_caravan()
		if n.is_empty():
			return "Away — on the road"
		var d := int(n.get("days", 0))
		return "Away — expected today" if d <= 0 else ("Away — next in ~%d day%s" % [d, "" if d == 1 else "s"])
	var hr: Array = v["hours"]
	if hr.is_empty():
		return "Always open"
	if in_hours(id, hour):
		return "Open until %s" % fmt_hour(int(hr[1]))
	return "Closed — opens %s" % fmt_hour(int(hr[0]))


## Why the counter cannot be used right now ("" when open).
static func closed_reason(id: String, hour := -1) -> String:
	return "" if is_open(id, hour) else status_text(id, hour)


# ------------------------------------------------------------------ goods
static func category_of(def: String) -> String:
	var d := DB.item(def)
	var t := str(d.get("type", ""))
	var tags: Array = d.get("tags", [])
	if t == "companion":
		return "Companion creatures"
	if t == "weapon":
		return "Weapons"
	if t.begins_with("armor") or t in ["helmet", "shield", "boots", "gloves", "cloak", "belt"]:
		return "Armour"
	if t in ["ring", "amulet"]:
		return "Jewellery"
	if t in ["relic", "curio"]:
		return "Curios & relics"
	if t == "potion":
		return "Potions"
	if def.begins_with("dragon_") or tags.has("dragon") or def.ends_with("_ash") or def.begins_with("troll_") or def.begins_with("wyvern_"):
		return "Monster parts"
	if def == "coal" or def.begins_with("charcoal"):
		return "Coal & fuel"
	if def.begins_with("ore_") or def.begins_with("ingot_") or def.contains("metal"):
		return "Ore & metal"
	if def.contains("leather") or def.contains("hide"):
		return "Hides & leather"
	if def.begins_with("thread_") or def.begins_with("wool_") or def.begins_with("flax_") or def.begins_with("cloth_") or tags.has("fibre"):
		return "Thread & fibre"
	if def.contains("stave") or def.begins_with("wood") or def.contains("timber"):
		return "Wood"
	if def.begins_with("herb_"):
		return "Herbs"
	if def.begins_with("reagent_") or tags.has("reagent"):
		return "Reagents"
	if def.begins_with("gem_"):
		return "Gems"
	return "Goods"


## Item defs a venue can deal in, from the stock data (and whatever is aboard / in the wagons right now).
static func stock_defs(id: String) -> Array:
	var v := get_v(id)
	var out: Array = []
	var src := str(v.get("stock", ""))
	if src.begins_with("trade:"):
		for e in Trade.cfg().get(src.substr(6), {}).get("stock", []):
			out.append(str(e[0]))
	match src:
		"harbour":
			for e in Trade.current_ship().get("stock", []):
				if str(e.get("def", "")) != "":
					out.append(str(e["def"]))
		"caravan":
			var cc: Dictionary = Commerce.cfg().get("caravan", {})
			for e in cc.get("stock", []) + cc.get("equipment", []):
				out.append(str(e[0]))
		"pawn":
			for e in Commerce.pawn_cfg().get("house_stock", []):
				out.append(str(e[0]))
		"rival":
			var rc := Commerce.rival_cfg()
			for e in rc.get("stock", []) + rc.get("materials", []):
				out.append(str(e[0]))
		"creatures":
			var cr := Commerce.creature_cfg()
			for e in cr.get("ordinary", []) + cr.get("magical", []):
				out.append(str(e[0]))
	var uniq: Array = []
	for d in out:
		if not uniq.has(d) and not DB.item(str(d)).is_empty():
			uniq.append(d)
	return uniq


## General merchandise categories (goods first, in a stable order) followed by the venue's services.
static func categories(id: String) -> Array:
	var seen := {}
	for d in stock_defs(id):
		seen[category_of(str(d))] = true
	var out: Array = []
	for c in CATEGORY_ORDER:
		if seen.has(c):
			out.append(c)
	if str(get_v(id).get("stock", "")) == "harbour" and Trade.current_ship().is_empty():
		out.append("Ships' goods when a ship is in")
	out.append_array(get_v(id).get("services", []))
	return out


## Venues that can sell `def`: [{id, name, note, price (unit, 0 = varies), sometimes (not every visit), open}].
static func selling(def: String) -> Array:
	var out: Array = []
	for src in ["general_store", "herbalist"]:
		for e in Trade.cfg().get(src, {}).get("stock", []):
			if str(e[0]) == def:
				var price := maxi(1, int(round(float(e[1]) * Trade.price_factor())))
				out.append(_sell(src, "fresh stock every morning (%d–%d a day)" % [int(e[2][0]), int(e[2][1])], price, false))
	for e in Trade.current_ship().get("stock", []):
		if str(e.get("def", "")) == def and int(e.get("qty", 0)) > 0:
			out.append(_sell("harbour", "aboard %s now" % str(Trade.current_ship().get("name", "the ship")), int(e["price"]), false))
	var imp := Trade.import_info(def)
	if not imp.is_empty() and Trade.knows(def):
		out.append(_sell("harbour", "special import, %d–%d days" % [int(imp["lead"][0]), int(imp["lead"][1])], int(imp["unit"]), false))
	for vid in ["caravan", "pawn", "rival_smith", "creatures"]:
		if stock_defs(vid).has(def):
			out.append(_sell(vid, "sometimes in stock" if vid != "caravan" else "sometimes in the wagons", 0, true))
	return out


static func selling_ids(def: String) -> Array:
	var out: Array = []
	for s in selling(def):
		if not out.has(s["id"]):
			out.append(s["id"])
	return out


static func _sell(id: String, note: String, price: int, sometimes: bool) -> Dictionary:
	return {"id": id, "name": str(get_v(id).get("name", id)), "note": note, "price": price, "sometimes": sometimes, "open": is_open(id)}


# ------------------------------------------------------------------ presentation
## One honest line for quick travel: what you can actually do there and when.
static func travel_line(id: String) -> String:
	var v := get_v(id)
	if v.is_empty():
		return ""
	var cats := categories(id)
	var what := ", ".join(cats.slice(0, 3)).to_lower() if not cats.is_empty() else ""
	var hrs := hours_text(id)
	if str(v.get("presence", "")) == "own":
		return "Your forge, stores and shop counter."
	if str(v.get("presence", "")) == "caravan":
		return "%s — %s." % [status_text(id), what]
	return "%s · %s." % [what.capitalize() if what != "" else str(v["type"]), hrs]


## Everything the map card shows (never the full stock).
static func card(id: String) -> Dictionary:
	var v := get_v(id)
	if v.is_empty():
		return {}
	var keeper := str(v.get("keeper", ""))
	return {"id": id, "name": str(v["name"]), "type": str(v["type"]), "status": status_text(id), "open": is_open(id),
		"hours": hours_text(id), "categories": categories(id), "interface": bool(v.get("interface", false)),
		"how": str(v.get("how", "")), "travel": str(v.get("travel", "")), "keeper": keeper,
		"keeper_name": Talk.npc_name(keeper) if keeper != "" else "", "panel": str(v.get("panel", ""))}
