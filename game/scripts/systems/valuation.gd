## Valuation — the one item-pricing interface (R2 "Truthful World Model"; TECH-030 consolidation, ECO-031 foundation).
## EN: Before R2 the same sums were written out in many places: the smith-buying difficulty factor twice, verbatim
##     (Trade.price_factor and Commerce.price_factor); a merchant's price for a catalogue item (catalogue value × a
##     markup × that factor) in the guide, the caravan, the import orders and the steward; and the cost of a Design's
##     materials three ways (the steward and its working smith at the village counters' price, the Workshop Ledger at the
##     bare catalogue value — so the same order showed one cost and was planned with another).
##     One interface now, with the existing formulas (no prices change except the Ledger's material cost, which now
##     matches what the steward plans with and what the counters really charge):
##       value(it)                 an item's worth (Items.value: base × rarity × craftsmanship × Epic, × qty);
##       unit_value(it)            the worth of one unit of a stack;
##       catalogue(def_id)         a def's catalogue value (data/items.json "value");
##       smith_buys_factor()       the difficulty factor when the smith buys (Apprentice cheaper, Master dearer);
##       buyers_factor()           the difficulty factor when buyers pay the smith (Shop.buyer_factor);
##       merchant_price(def, mult) what a merchant asks the smith for one unit (catalogue × markup × smith_buys_factor);
##       counter_price(def_id)     a village counter's list price for a def ({store, price} or {} — never touches stock);
##       material_cost(def_id, n)  what n units cost to get: the village counter's price, else the merchant's at ×1;
##       design_material_cost(rid, n)  all of a Design's inputs for n pieces.
##     "Value to this person" (usefulness, needs, relationship) is Gate F's part of ECO-031 and is not invented here.
## DA: Ét fælles prisgrundlag: værdi, sværhedsfaktorer, købmandspriser og materialeomkostninger.
class_name Valuation
extends RefCounted

## The village counters whose list prices count as "what it costs to get" (the steward's material planning uses them).
const VILLAGE_STORES := ["general_store", "herbalist"]


static func value(it: Dictionary) -> int:
	return Items.value(it)


static func unit_value(it: Dictionary) -> int:
	var one := it.duplicate()
	one["qty"] = 1
	return maxi(1, Items.value(one))


static func catalogue(def_id: String) -> int:
	return int(DB.item(def_id).get("value", 5))


## When the smith buys: on Apprentice (prices 1.15) goods are cheaper, on Master (0.9) dearer.
static func smith_buys_factor() -> float:
	return 1.0 / maxf(0.5, float(Expeditions.diff().get("prices", 1.0)))


## When buyers pay the smith: Apprentice buyers pay a little more, Master buyers haggle harder.
static func buyers_factor() -> float:
	return float(Expeditions.diff().get("prices", 1.0))


## What a merchant asks the smith for one unit of a catalogue item at markup `mult`.
static func merchant_price(def_id: String, mult := 1.0) -> int:
	return maxi(1, int(round(float(catalogue(def_id)) * mult * smith_buys_factor())))


## A village counter's list price for a def (from the trade data; never touches today's stock): {store, price} or {}.
static func counter_price(def_id: String) -> Dictionary:
	for sid in VILLAGE_STORES:
		for e in Trade.store_cfg(sid).get("stock", []):
			if str(e[0]) == def_id:
				return {"store": sid, "price": maxi(1, int(round(float(e[1]) * smith_buys_factor())))}
	return {}


## What `n` units of a material cost to get: the village counter's price when a counter sells it, else the catalogue
## value (what a merchant asks at no markup) — one rule for the steward's planning, its working smith and the Ledger.
static func material_cost(def_id: String, n := 1) -> int:
	var cp := counter_price(def_id)
	return n * (int(cp["price"]) if not cp.is_empty() else catalogue(def_id))


## All of a Design's inputs for `n` pieces.
static func design_material_cost(rid: String, n := 1) -> int:
	var cost := 0
	var inputs: Dictionary = DB.recipe(rid).get("inputs", {})
	for d in inputs:
		cost += material_cost(str(d), int(inputs[d]) * n)
	return cost
