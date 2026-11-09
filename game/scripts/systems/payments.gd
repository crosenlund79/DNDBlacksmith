## Payments — who pays whom (Milestone A2, canon §7.3 and decision D14: "payments have real payers; subsidies are
## explicit and recorded").
## EN: Every coin that enters or leaves the smith's purse goes through Game.add_gold(amount, category, note, party);
##     `party` is the other side: an NPC id (an adventurer pays from their own purse, which goes down by the same
##     amount; a villager pays from their household; the smith pays a vendor or a worker), or a recorded outside party
##     (the village's outfitting subsidy, the caravan, the pawnbroker, a patron …). This file names those parties,
##     sums a person's business with the forge (gift_budget: a thank-you is worth at most GIFT_SHARE of what they paid
##     the forge in the last GIFT_DAYS days) and audits the ledger (lines without a payer or recipient).
## DA: Hvem betaler hvem: hver ledger-linje navngiver modparten (en person eller en registreret ekstern part).
class_name Payments
extends RefCounted

## The village of Brindlewick's outfitting purse: the subsidy toward adventurers' commissions (Shop.fulfil).
const VILLAGE := "village"
## A gift (a thank-you purse, a commission's reward package) is worth at most this share of the business that
## occasioned it — before A2 they came straight from the open loot tables (a mean of 118 g per thank-you gift and 935 g
## per reward package, whatever the giver had paid).
const GIFT_SHARE := 0.5
const GIFT_DAYS := 30

## Outside parties that keep no simulated purse in the game, by ledger id (people are named by their NPC id).
const PARTY_WORD := {
	"village": "the village outfitting purse", "reeve": "the reeve (rent and coal)", "village_trades": "the village tradesmen",
	"caravan": "the Brask caravan", "pawnbroker": "the pawnbroker", "rival_smith": "the Salt Anvil", "hale_farm": "Hale Farm",
	"collector": "a collector", "market": "buyers at the market", "dice": "dice players at the Wyvern", "ironfront": "Ironfront players",
	"inn": "the Wyvern's Rest", "lantern": "the Velvet Lantern", "harbourmaster": "the harbourmaster", "ships": "ships' captains",
	"skill_teacher": "a teacher", "dev": "developer tools", "apprentices": "the apprentices", "hirelings": "the hirelings",
	"lift_rigger": "the lift-riggers", "property_seller": "the property's seller"}


## A readable name for a ledger party ("" for none).
static func party_name(p: String) -> String:
	if p == "":
		return ""
	if PARTY_WORD.has(p):
		return str(PARTY_WORD[p])
	if p.begins_with("patron:"):
		return Contracts.patron_name(p.trim_prefix("patron:"))
	if p.begins_with("store:"):
		return Trade.store_name(p.trim_prefix("store:"))
	var c := DB.character(p)
	return str(c.get("name", p)) if not c.is_empty() else p


## The ledger party for a village store: its keeper when it has one (Pell's Provisions → aldric), else the store.
static func store_party(store_id: String) -> String:
	var k := str(Trade.store_cfg(store_id).get("keeper", ""))
	return k if k != "" else "store:" + store_id


## Gold that changed hands between `npc` and the forge in the last `days` days (both directions, from the ledger).
static func business_with(npc: String, days := GIFT_DAYS) -> int:
	var tot := 0
	var since := Game.day() - days
	for e in Game.state.get("ledger", []):
		if str(e.get("party", "")) == npc and int(e.get("day", 0)) > since:
			tot += absi(int(e["amount"]))
	return tot


## The gifts `npc` gave the smith in the last GIFT_DAYS days: [[day, value]] (kept on their social record).
static func _gifts(npc: String) -> Array:
	var e: Dictionary = Social.ensure(npc)
	if not e.has("gift_log"):
		e["gift_log"] = []
	var keep := (e["gift_log"] as Array).filter(func(g): return int(g[0]) > Game.day() - GIFT_DAYS)
	e["gift_log"] = keep
	return keep


## What a thank-you gift from `npc` may be worth today: GIFT_SHARE of their recent business with the forge, less what
## they already gave in that time.
static func gift_budget(npc: String) -> int:
	var given := 0
	for g in _gifts(npc):
		given += int(g[1])
	return maxi(0, int(float(business_with(npc)) * GIFT_SHARE) - given)


static func note_gift(npc: String, value: int) -> void:
	_gifts(npc).append([Game.day(), value])


## The cheapest of `items` first, while the total stays within `cap` gold (Items.value). [] when nothing fits.
static func gift_within(items: Array, cap: int) -> Array:
	var sorted := items.duplicate()
	sorted.sort_custom(func(x, y): return Items.value(x) < Items.value(y))
	var out := []
	var tot := 0
	for it in sorted:
		var v := Items.value(it)
		if tot + v > cap:
			break
		out.append(it)
		tot += v
	return out


static func value_of(items: Array) -> int:
	var v := 0
	for it in items:
		v += Items.value(it)
	return v


## Ledger lines that name no payer (income) or recipient (expense): [{day, amount, cat, note}].
## `since_day`: only lines from that day on (ledger lines written before A2 have no party).
static func unaccounted(since_day := 0) -> Array:
	var out := []
	for e in Game.state.get("ledger", []):
		if int(e.get("day", 0)) >= since_day and int(e.get("amount", 0)) != 0 and str(e.get("party", "")) == "":
			out.append(e)
	return out
