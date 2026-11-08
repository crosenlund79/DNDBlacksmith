## Knowledge — purchasable hints and specialist knowledge for genuinely hidden things.
## EN: Ordinary instructions are free (Guide). A few villagers sell what they alone know, through their own
##     counters: Silas Quell (old notes: forgotten recipes, rune lore, the deep galleries), the harbourmaster
##     (dragon lore, exotic cargo) and Maud Fennimore (where the wild herbs grow). A HINT tells where/how to
##     earn a discovery — it never sets the discovery itself. "Complete knowledge" may grant non-progression
##     knowledge (e.g. the names of exotic cargo, which lets the harbourmaster take an import order) — never a
##     skill-tree, recipe or station gate. Bought knowledge persists and is listed in the encyclopedia.
## DA: Købbare hint og særlig viden om skjulte ting. Et hint fortæller hvor/hvordan; det giver ikke opdagelsen.
##
## Public API (static):
##   offers(seller) -> Array[{id, seller, kind "hint"|"knowledge", title, teaser, price, bought, can_buy, why}]
##   buy(id) -> String ("" = ok)        owned(id) -> bool        owned_list() -> Array[offer + {day}]
##   offer(id) -> Dictionary            seller_name(seller) -> String
## State: Game.state["knowledge"] = {"bought": {offer_id: day}} (created lazily — old saves gain it on first use).
class_name Knowledge
extends RefCounted

## done_flag: once the player knows the thing anyway, the offer is no longer for sale (unless already bought).
## requires_flag: offered only once this is known (keeps hidden things hidden). grants: flags set by KNOWLEDGE only.
const OFFERS := [
	{"id": "hint_forgotten_recipes", "seller": "pawnbroker", "kind": "hint", "price": 45, "done_flag": "recipe_starsteel",
		"title": "Old notes: forgotten recipes",
		"teaser": "Quell has bought the papers of dead smiths. Some recipes were never written in any book.",
		"text": "Weathered tablets turn up in hauls from the old barrows (the Barrow Fields, and older ruins once you find them). Study one from your inventory (or give a hireling relic-hunting work) and now and then the tablet holds an old smith's notes: a Forgotten Recipe scroll. Read the scroll in your inventory to learn it."},
	{"id": "hint_rune_lore", "seller": "pawnbroker", "kind": "hint", "price": 30, "done_flag": "rune_knowledge",
		"title": "Old notes: rune lore",
		"teaser": "The runesmiths of old left their knowledge in stone, not ink.",
		"text": "Rune lore is learned by restoring an original runestone from a weathered tablet: the Restore Runestone work at the Rune Cleansing Basin and Rune Polishing Wheel. Tablets come from barrow hauls; the skill tree's runecrafting branch opens the stations."},
	{"id": "hint_deep_galleries", "seller": "pawnbroker", "kind": "hint", "price": 35, "done_flag": "delve_map",
		"title": "Old notes: the deep galleries",
		"teaser": "A miner's ledger mentions galleries below the Ironroot that no one walks any more.",
		"text": "The way down into Deep Ironroot is on an old miner's map. Such maps turn up — rarely — in hauls from the Ironroot Mine. Keep sending miners; once the map is in your stores, the deep galleries are open to hirelings and adventurers."},
	{"id": "hint_dragon_lore", "seller": "harbourmaster", "kind": "hint", "price": 50, "done_flag": "dragon_lore",
		"title": "Dragon lore",
		"teaser": "The old armourers knew how to work dragon. The whalers know where it comes from.",
		"text": "Dragon lore cannot be bought, only learned: hold a dragon's scale or bone and sit up with it. The far-north whaler sometimes carries both; once your skill tree covers exotic monster materials, the harbourmaster can order them from abroad as well."},
	{"id": "know_exotic_cargo", "seller": "harbourmaster", "kind": "knowledge", "price": 120,
		"grants_heard": ["ore_orichalcum", "wyvern_hide", "reagent_wyrm_ash", "gem_starstone"],
		"title": "Exotic cargo manifests",
		"teaser": "The manifests of the far ports: goods most smiths never hear of, and which I can order for you once you know to ask.",
		"text": "You now know of orichalcum ore, wyvern hide, wyrm ash and starstone: the harbourmaster will take special import orders for them (the far ports are slow and dear)."},
	{"id": "hint_wild_herbs", "seller": "herbalist", "kind": "hint", "price": 15,
		"title": "Where the wild herbs grow",
		"teaser": "Maud knows every glade from here to the barrows.",
		"text": "Bloodroot, frostcap and silverleaf grow wild in Whisperwood's Bloodroot hollow and herb glade: hirelings bring them home from Whisperwood, and adventurers offer what they pick. Scout Whisperwood often enough and the herb-wives will sell to your trade runs too."},
]
const SELLERS := {"pawnbroker": "Silas Quell, the pawnbroker", "harbourmaster": "the harbourmaster", "herbalist": "Maud Fennimore, the herbalist"}


static func st() -> Dictionary:
	if not Game.state.has("knowledge"):
		Game.state["knowledge"] = {"bought": {}}
	var k: Dictionary = Game.state["knowledge"]
	if not k.has("bought") or not (k["bought"] is Dictionary):
		k["bought"] = {}
	return k


static func offer(id: String) -> Dictionary:
	for o in OFFERS:
		if str(o["id"]) == id:
			return o
	return {}


static func seller_name(seller: String) -> String:
	return str(SELLERS.get(seller, seller))


static func owned(id: String) -> bool:
	return Game.state.has("knowledge") and (st()["bought"] as Dictionary).has(id)


static func _price(o: Dictionary) -> int:
	return maxi(1, int(round(float(o["price"]) * Trade.price_factor())))


## Is there still anything to learn from this offer?
static func _relevant(o: Dictionary) -> bool:
	if str(o.get("requires_flag", "")) != "" and not Game.has_flag(str(o["requires_flag"])):
		return false
	if str(o.get("done_flag", "")) != "" and Game.has_flag(str(o["done_flag"])):
		return false
	if o.has("grants_heard"):
		for d in o["grants_heard"]:
			if not Trade.knows(str(d)):
				return true
		return false
	return true


## What a seller offers now: bought ones stay listed (to reread); irrelevant unbought ones are not offered.
static func offers(seller: String) -> Array:
	var out := []
	for o in OFFERS:
		if str(o["seller"]) != seller:
			continue
		var b := owned(str(o["id"]))
		if not b and not _relevant(o):
			continue
		var price := _price(o)
		var why := "" if b or Game.can_afford(price) else "You need %d g." % price
		out.append({"id": o["id"], "seller": seller, "kind": o["kind"], "title": o["title"], "teaser": o["teaser"], "price": price,
			"bought": b, "can_buy": not b and why == "", "why": why, "text": o["text"] if b else ""})
	return out


static func buy(id: String) -> String:
	var o := offer(id)
	if o.is_empty():
		return "Nobody sells that."
	if owned(id):
		return "You already know it."
	if not _relevant(o):
		return "There is nothing more to learn there."
	var price := _price(o)
	if not Game.can_afford(price):
		return "You need %d g." % price
	Game.add_gold(-price, "training", "Knowledge: " + str(o["title"]))
	st()["bought"][id] = Game.day()
	for d in o.get("grants_heard", []):
		Game.set_flag("heard_" + str(d))
	Game.journal("I paid %s %d g for what they know: %s." % [seller_name(str(o["seller"])), price, str(o["title"]).to_lower()])
	Chronicle.add("knowledge", "Brannoc bought knowledge from %s: %s." % [seller_name(str(o["seller"])), str(o["title"])], {"npc": str(o["seller"])})
	return ""


## Everything bought, oldest first: offer + {day}.
static func owned_list() -> Array:
	var out := []
	if not Game.state.has("knowledge"):
		return out
	var b: Dictionary = st()["bought"]
	for o in OFFERS:
		if b.has(str(o["id"])):
			var e: Dictionary = o.duplicate()
			e["day"] = int(b[str(o["id"])])
			e["seller_name"] = seller_name(str(o["seller"]))
			out.append(e)
	out.sort_custom(func(a, c): return int(a["day"]) < int(c["day"]) or (int(a["day"]) == int(c["day"]) and str(a["id"]) < str(c["id"])))
	return out
