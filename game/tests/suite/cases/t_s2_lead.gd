## S2 lead fixes found while integrating the workers' work.
##   D14: a commission's reward package is worth at most Payments.GIFT_SHARE of what the GIVER paid (their own share),
##        not of the whole reward (part of which is the village's subsidy) — a customer who paid nothing gives nothing.
extends SuiteCase

const SMOKE := ["test_reward_package_capped_by_the_givers_own_payment"]


func _adv(id: String) -> Dictionary:
	var a := Adv.get_a(id)
	a["status"] = "in_town"
	return a


func _deliver_rare(id: String, purse: int) -> Dictionary:
	var a := _adv(id)
	a["gold"] = purse
	var o := Shop.create_order(id, "weapon", "test")
	if o.is_empty():
		return {}
	o["min"] = 1
	o["tier"] = 1
	o.erase("bonus")
	var it := Items.make("sword_iron", {"quality": 95.0})
	Items.apply_rarity(it, "rare")   # exceptional work: a reward package is possible
	Game.add_item(it, false)
	var r0 := (Game.state["returns"] as Array).size()
	var err := Shop.fulfil(str(o["id"]), int(it["uid"]))
	var pkgs: Array = (Game.state["returns"] as Array).slice(r0).filter(func(b): return str(b.get("def", "")) == "package_reward")
	return {"err": err, "order": o, "pkgs": pkgs}


func test_reward_package_capped_by_the_givers_own_payment() -> void:
	fresh_game()
	# a penniless customer: the village pays the whole commission, the customer gives nothing
	for i in 12:
		seed(4100 + i)
		var r := _deliver_rare("rv_liesl", 0)
		if not check(not r.is_empty() and str(r["err"]) == "", "a commission delivered to Liesl (%s)" % str(r.get("err", ""))):
			return
		eq(int(r["order"]["paid"]["gold"]), 0, "Liesl paid nothing (the subsidy covered it)")
		eq((r["pkgs"] as Array).size(), 0, "so she leaves no reward package (D14: no gift without a giver's means)")
	# a customer who pays: any package is worth at most half of their own share
	var seen := 0
	for i in 20:
		seed(4200 + i)
		var r2 := _deliver_rare("garrick", 2000)
		if r2.is_empty():
			continue
		var paid := int(r2["order"]["paid"]["gold"])
		for b in r2["pkgs"]:
			seen += 1
			check(Payments.value_of(b.get("contents", [])) <= int(float(paid) * Payments.GIFT_SHARE),
				"a package (%d g) is within half of what Garrick paid (%d g)" % [Payments.value_of(b.get("contents", [])), paid])
	note("%d reward packages from a paying customer, each within half of his own share" % seen)
