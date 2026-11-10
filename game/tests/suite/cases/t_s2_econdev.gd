## Milestone S2 — the ECONDEV worker: equipment affordability, commerce verification and the developer tools.
##  · an adventurer's saving goal (Adv.price_estimate) is the price the shop really asks for that piece (rarity,
##    craftsmanship, Display Cases, difficulty), and what they think fair moves with the difficulty like the price does;
##  · the Salt Anvil charges adventurers with the same buyers' difficulty factor as the smith's display (before: the
##    smith-buying factor, so Maren undercut the smith on Apprentice and overcharged on Master);
##  · plain common pieces at the Salt Anvil put ordinary gear within starting purses on every difficulty, without any
##    new crafting ability for the smith, and rarity and craftsmanship keep their worth;
##  · the once-per-friend gratitude relic is bounded like every other gift;
##  · a 60-day seeded game: every ledger line names its payer or recipient, and every payment by an adventurer leaves
##    their own purse (conserved);
##  · consultations: a gear-seeker is not told to keep their coin ahead of a piece they would buy; the Salt Anvil advice
##    names a real plain piece at the adventurer's price; a sale keeps uid, maker and story;
##  · developer cheats: off by default, never saved, off after a new game or a load, a visible banner while on, the
##    skill-check bypass only while on, and a game played with cheats on is marked.
extends SuiteCase

const SMOKE := ["test_price_estimate_is_the_shop_price", "test_salt_anvil_fair_on_every_difficulty", "test_cheats_off_by_default"]
const DIFFS := ["apprentice", "journeyman", "master"]
const SEEDS := [9001, 4242, 777, 31337]


# ------------------------------------------------------------------ fixtures
func _adv(id: String) -> Dictionary:
	var a := Adv.get_a(id)
	Expeditions.ensure(a)
	a["status"] = "in_town"
	Shop.remove_customer(id)
	return a


## A buyer with no gear or saving goal, neither liked nor disliked, in a village that hardly knows the smith.
func _neutral(a: Dictionary) -> void:
	a["goals"] = []
	Social.ensure(str(a["id"]))["aff"] = 0.0
	Game.state["world"]["rep"] = 0.0


func _suitable(a: Dictionary, it: Dictionary) -> bool:
	var s := Items.slot(it)
	return s != "" and Adv.affinity(a, it) > 0.0 and Items.score(it) > Items.score(a["equipment"].get(s, {})) + 1.0


## Maren's equipment over `n` restocks (what an adventurer could find over several weeks): [{item, adv, entry}].
func _anvil_catalogue(n: int) -> Array:
	var out := []
	for k in n:
		Commerce.st()["rival"].erase("stock")
		for e in Commerce.rival_stock():
			if e.has("item"):
				out.append({"item": e["item"], "adv": Commerce.rival_adv_price(e), "entry": e})
	Commerce.st()["rival"].erase("stock")
	return out


# ------------------------------------------------------------------ 1. the saving goal is the shop's real price
func test_price_estimate_is_the_shop_price() -> void:
	for diff in DIFFS:
		for cases in [false, true]:
			fresh_game(diff, 9001)
			if cases:
				Game.state["upgrades"].append("display_cases")
			var a := _adv("kestra")
			for slot in ["weapon", "armor", "helmet", "boots"]:
				var goal := Adv.price_estimate(a, slot)
				# the piece the goal aims for, as the display would price a plain one
				var best := 0
				var def := ""
				for id in DB.items:
					var d: Dictionary = DB.items[id]
					if str(d.get("slot", "")) == slot and Adv.affinity(a, {"def": id}) > 0.0 and int(d.get("value", 0)) <= 60 + int(a["level"]) * 45 and int(d.get("value", 0)) > best:
						best = int(d.get("value", 0))
						def = str(id)
				if def == "":
					continue
				var plain := Items.make(def, {"quality": Adv.ESTIMATE_QUALITY, "rarity": "common"})
				eq(goal, Shop.price_of(plain), "%s%s: the %s goal is the display price of a plain %s" % [diff, " + cases" if cases else "", slot, def])
				var magic := Items.make(def, {"quality": Adv.ESTIMATE_QUALITY, "rarity": "magic"})
				eq(Adv.price_estimate(a, slot, "magic"), Shop.price_of(magic), "%s: a magic %s is priced with its rarity" % [diff, def])
	# the goal an adventurer actually saves for is that price
	fresh_game("apprentice", 9001)
	var b := _adv("kestra")
	b["gold"] = 1
	b["equipment"].erase("weapon")
	Adv.evaluate_gear(b)
	var sv: Dictionary = b.get("saving_for", {})
	if check(not sv.is_empty(), "with 1 g Kestra saves up (%s)" % str(b.get("shopping", []))):
		eq(int(sv["goal"]), Adv.price_estimate(b, str(sv["slot"])), "her saving goal is the shop's price of the piece she has in mind")
	note("before S2 the goal was the item's bare value × 1.05: on Apprentice a level-1 Ranger's weapon goal was 73 g for a 87 g piece")


# ------------------------------------------------------------------ 2. Salt Anvil and display: one buyers' factor
func test_salt_anvil_fair_on_every_difficulty() -> void:
	var worst := 0.0
	var markup := {}
	for diff in DIFFS:
		fresh_game(diff, 4242)
		var cat := _anvil_catalogue(3)
		check(not cat.is_empty(), "%s: Maren has work on her bench" % diff)
		for c in cat:
			var e: Dictionary = c["entry"]
			var it: Dictionary = c["item"]
			eq(int(c["adv"]), maxi(1, int(round(float(e["base"]) * Shop.buyer_factor()))), "%s: an adventurer pays her asking price × the buyers' factor" % diff)
			eq(int(e["price"]), maxi(1, int(round(float(e["base"]) * Commerce.price_factor()))), "%s: the smith pays her asking price × the smith-buying factor" % diff)
			# against the display price of the very same piece: her markup, whatever the difficulty (± rounding)
			var mult := float(e["base"]) / float(Items.value(it))
			var expect := float(Shop.list_price(it)) * mult
			worst = maxf(worst, absf(float(c["adv"]) - expect) / maxf(1.0, expect))
			if float(Shop.list_price(it)) >= 100.0:
				var key := "%s ×%.2f" % [diff, mult]
				markup[key] = snappedf(float(c["adv"]) / float(Shop.list_price(it)), 0.01)
		# an old stock entry (no `base`) is priced the same within a coin
		var e0: Dictionary = (cat[0]["entry"] as Dictionary).duplicate()
		e0.erase("base")
		check(absi(Commerce.rival_adv_price(e0) - int(cat[0]["adv"])) <= 1, "%s: stock rolled before S2 is priced the same (±1 g)" % diff)
	check(worst < 0.1, "at the Salt Anvil an adventurer pays the display price of the same piece × her markup on every difficulty (worst deviation %.1f %%, rounding of small prices)" % (worst * 100.0))
	note("Salt Anvil ÷ display price for the same piece (≥ 100 g): %s — before S2 Apprentice ×0.76 and Master ×1.23 of the markup" % JSON.stringify(markup))
	# a purchase takes exactly the adventurer's price out of their purse, and the piece keeps Maren's story
	fresh_game("apprentice", 4242)
	var a := _adv("kestra")
	a["gold"] = 5000
	a["equipment"].clear()
	var o := Commerce.rival_offer_for(a)
	if check(not o.is_empty(), "a well-off, unequipped adventurer finds something at the Salt Anvil"):
		var entry: Dictionary = Commerce.rival_stock()[int(o["index"])]
		eq(int(o["price"]), Commerce.rival_adv_price(entry), "the offer quotes the adventurer's price")
		var uid := int((o["item"] as Dictionary)["uid"])
		var g0 := int(a["gold"])
		var got := Commerce.rival_buy_for(a)
		eq(g0 - int(a["gold"]), int(o["price"]), "her purse goes down by that price")
		var worn: Dictionary = a["equipment"][str(got["slot"])]
		eq(int(worn["uid"]), uid, "she wears Maren's very piece (same uid)")
		eq(str(Provenance.maker(worn).get("name", "")), "Maren Tallowgate", "Maren is still its maker")
	# a class that never uses a shield does not buy one there
	var rg := _adv("kestra")
	rg["gold"] = 5000
	for e in Commerce.rival_stock():
		if e.has("item") and Adv.affinity(rg, e["item"]) <= 0.0:
			var oo := Commerce.rival_offer_for(rg)
			check(oo.is_empty() or Adv.affinity(rg, oo["item"]) > 0.0, "the Salt Anvil offers only what the class would use")
			break
	# what a neutral buyer thinks fair: the default price passes on every difficulty, with and without Display Cases
	for diff in DIFFS:
		for cases in [false, true]:
			fresh_game(diff, 9001)
			if cases:
				Game.state["upgrades"].append("display_cases")
			var k := _adv("kestra")
			_neutral(k)
			k["gold"] = 5000
			k["equipment"].erase("weapon")
			var sw := Items.make("sword_iron", {"quality": 80.0, "rarity": "common"})
			Game.add_item(sw, false)
			eq(Adv.purchase_check(k, sw, Shop.price_of(sw)), "", "%s%s: a neutral buyer takes the default price (%d g)" % [diff, " + Display Cases" if cases else "", Shop.price_of(sw)])
			eq(Adv.purchase_check(k, sw, int(Shop.price_of(sw) * 1.3)), "thinks it's overpriced", "%s: 30 %% above it is still too dear" % diff)
	note("before S2 a neutral buyer on Apprentice refused the default price, even without Display Cases (75 g > fair 74.75 g)")


# ------------------------------------------------------------------ 3. affordable ordinary choices
func test_affordable_ordinary_choices() -> void:
	var cheapest := {}
	for diff in DIFFS:
		var core := 0
		var core_ok := 0
		var per_slot := {}
		for sd in SEEDS:
			fresh_game(diff, sd)
			var locked_boots := Shop.can_make_slot("boots")
			var cat := _anvil_catalogue(8)
			for c in cat:
				var e: Dictionary = c["entry"]
				if not bool(e.get("plain", false)):
					continue
				var it: Dictionary = c["item"]
				check(str(it["rarity"]) == "common" and float(it["quality"]) >= 62.0 and float(it["quality"]) <= 78.0, "plain work is common, ordinary craftsmanship (%s %.0f%%)" % [it["rarity"], float(it["quality"])])
				check(str(Provenance.maker(it).get("name", "")) == "Maren Tallowgate" and int(it["uid"]) > 0, "a real piece with Maren's mark")
				var slot := Items.slot(it)
				var key := "%s/%s" % [diff, slot]
				cheapest[key] = mini(int(cheapest.get(key, 1 << 30)), int(c["adv"]))
			for a in Adv.all().values():
				if str(a.get("origin", "")) != "start":
					continue
				for need in Adv.gear_needs(a):
					if str(need["why"]) == "extra" or str(need["slot"]) == "companion":
						continue
					core += 1
					var best := 1 << 30
					for c2 in cat:
						if Items.slot(c2["item"]) == str(need["slot"]) and _suitable(a, c2["item"]):
							best = mini(best, int(c2["adv"]))
					for r in DB.recipes.values():
						var out := str(r.get("output", ""))
						if str(DB.item(out).get("slot", "")) != str(need["slot"]) or Crafting.recipe_locked_reason(str(r["id"])) != "":
							continue
						var piece := Items.make(out, {"quality": 80.0, "rarity": "common"})
						if _suitable(a, piece):
							best = mini(best, Shop.price_of(piece))
					if best <= int(a["gold"]):
						core_ok += 1
						per_slot[str(need["slot"])] = int(per_slot.get(str(need["slot"]), 0)) + 1
			# no new crafting ability came with it
			eq(Shop.can_make_slot("boots"), locked_boots, "%s: the smith's own Designs are unchanged (boots)" % diff)
		var share := float(core_ok) / maxf(1.0, core)
		check(share >= 0.55, "%s: %d of %d core needs of starting adventurers have an affordable ordinary piece (%.0f %%; before S2 about 40 %%)" % [diff, core_ok, core, share * 100.0])
		note("%s: affordable core needs %d/%d by slot %s" % [diff, core_ok, core, JSON.stringify(per_slot)])
	# the median starting purse (≈ 85 g) buys plain boots, gloves or a belt at the Salt Anvil — pieces a new forge cannot
	# make — and a plain weapon, helmet or shield from the smith's own Designs, on every difficulty
	for diff in DIFFS:
		fresh_game(diff, 9001)
		for slot in ["boots", "gloves", "belt"]:
			var p := int(cheapest.get("%s/%s" % [diff, slot], 1 << 30))
			check(p <= 85, "%s: plain %s at the Salt Anvil cost %d g (≤ 85 g, the median starting purse)" % [diff, slot, p])
		for slot2 in ["weapon", "helmet", "shield"]:
			var best := 1 << 30
			for r in DB.recipes.values():
				var out := str(r.get("output", ""))
				if str(DB.item(out).get("slot", "")) == slot2 and Crafting.recipe_locked_reason(str(r["id"])) == "":
					best = mini(best, Shop.price_of(Items.make(out, {"quality": 80.0, "rarity": "common"})))
			check(best <= 85, "%s: the smith's own plain %s (80 %%) is on display for %d g (≤ 85 g)" % [diff, slot2, best])
		note("%s: cheapest plain armour at the Salt Anvil (mail) %d g" % [diff, int(cheapest.get("%s/armor" % diff, -1))])
	# rarity and craftsmanship keep their worth
	var c0 := Items.make("sword_iron", {"quality": 80.0, "rarity": "common"})
	var m0 := Items.make("sword_iron", {"quality": 80.0, "rarity": "magic"})
	var r0 := Items.make("sword_iron", {"quality": 80.0, "rarity": "rare"})
	var hq := Items.make("sword_iron", {"quality": 110.0, "rarity": "common"})
	check(Items.value(m0) >= int(Items.value(c0) * 1.75) and Items.value(r0) >= int(Items.value(c0) * 2.9), "magic and rare are still worth ×1.8 and ×3 (%d / %d / %d g)" % [Items.value(c0), Items.value(m0), Items.value(r0)])
	check(Items.value(hq) > Items.value(c0), "fine craftsmanship is still worth more (%d g > %d g)" % [Items.value(hq), Items.value(c0)])


# ------------------------------------------------------------------ 4. the gratitude relic is bounded (BUG-045)
func _gifts_from(name: String) -> Array:
	return (Game.state["returns"] as Array).filter(func(r): return str(r.get("from", "")) == name)


func test_gratitude_gift_bounded() -> void:
	fresh_game("journeyman", 9001)
	var a := _adv("kestra")
	Social.ensure("kestra")["aff"] = 90.0
	eq(Social.band("kestra"), "devoted", "Kestra is devoted to the smith")
	for npc in Game.state["social"]:
		if str(npc) != "kestra":
			Game.state["social"][npc]["aff"] = 0.0
	(Game.state["returns"] as Array).clear()
	# no business with the forge: never a relic, however devoted
	for i in 60:
		seed(1000 + i)
		Sim._social_events()
	check(_gifts_from(str(a["name"])).is_empty(), "with no business this month, Kestra leaves nothing (before S2 the relic satchel came anyway)")
	check(not Social.has_memory("kestra", "gave_relic"), "and the once-only relic is still to come")
	# 240 g of business: everything she leaves this month is worth at most 120 g
	Game.add_gold(240, "sales", "Sold Kestra a blade", "kestra")
	for i in 120:
		seed(2000 + i)
		Sim._social_events()
	var total := 0
	for g in _gifts_from(str(a["name"])):
		total += Payments.value_of(g.get("contents", []))
	check(total <= 120, "all she left this month is worth %d g (≤ half of 240 g)" % total)
	var logged := 0
	for g2 in (Social.ensure("kestra").get("gift_log", []) as Array):
		logged += int(g2[1])
	eq(logged, total, "every gift is in her gift log")
	if Social.has_memory("kestra", "gave_relic"):
		note("the gratitude relic came within the budget (%d g in all)" % total)


# ------------------------------------------------------------------ 5. 60 days: every coin has a payer, purses conserve
var _snaps: Array = []


## Every adventurer's purse, after each ledger line (gold_changed) and at each tick of the test's own clock.
func _snap(_total: int) -> void:
	_snaps.append({"last": (Game.state["ledger"] as Array)[-1] if not (Game.state["ledger"] as Array).is_empty() else {}, "purses": _purses()})


func _tick() -> void:
	_snaps.append({"last": {}, "purses": _purses()})


func _purses() -> Dictionary:
	var p := {}
	for id in Adv.all():
		p[str(id)] = int(Adv.all()[id].get("gold", 0))
	return p


func test_ledger_60_days_conserved() -> void:
	fresh_game("journeyman", 6060)
	_snaps = []
	Events.gold_changed.connect(_snap)
	var consults := 0
	for d in 60:
		# the smith keeps a little ordinary work on display and serves the counter
		for a in Adv.in_town():
			for need in Adv.gear_needs(a).slice(0, 1):
				var cap := Shop.slot_capability(str(need["slot"]), a)
				if str(cap["state"]) in ["now", "materials"] and Shop.stock().size() < 5:
					var it := Items.make(str(DB.recipe(str(cap["recipe"])).get("output", "")), {"quality": 85.0})
					it["for_sale"] = true
					Game.add_item(it, false)
		for o in Shop.open_orders():
			var cap2 := Shop.slot_capability(str(o["slot"]))
			if o.has("def") or str(cap2["state"]) == "locked":
				continue
			var it2 := Items.make(str(DB.recipe(str(cap2["recipe"])).get("output", "")), {"quality": 100.0})
			Game.add_item(it2, false)
			if Shop.item_meets(o, it2):
				Shop.fulfil(str(o["id"]), int(it2["uid"]))
			else:
				Game.take_uid(int(it2["uid"]))
		# a consultation now and then: the first advice is put forward
		if d % 6 == 3:
			_tick()
			for a2 in Adv.in_town():
				if Consult.can_approach(a2):
					var ses := Consult.session(str(a2["id"]))
					if not (ses.get("recs", []) as Array).is_empty():
						Consult.advise(str(a2["id"]), str(ses["recs"][0]["id"]))
						Consult.finish(str(a2["id"]))
						consults += 1
					break
		_tick()
		for h in 24:
			Game.advance_minutes(60)
			_tick()
			for c in Shop.customers().duplicate():
				if not bool(c.get("present", false)):
					Shop.mark_arrived(str(c["npc"]), false)
			for c2 in Shop.waiting().duplicate():
				if str(c2.get("want", "")) == "repair":
					Shop.do_repair(str(c2["npc"]), 85.0)
					_tick()
	Events.gold_changed.disconnect(_snap)
	# every line names a known payer or recipient
	var unknown := []
	var by_party := {}
	for l in Game.state["ledger"]:
		var p := str(l.get("party", ""))
		var known := p != "" and (Payments.PARTY_WORD.has(p) or not DB.character(p).is_empty() or p.begins_with("patron:")
			or p.begins_with("store:") or p.begins_with("hire_"))
		if not known:
			unknown.append("day %d %+d %s «%s» '%s'" % [int(l["day"]), int(l["amount"]), str(l["cat"]), str(l["note"]), p])
		var kind := "adventurer" if str(DB.character(p).get("kind", "")) == "adventurer" else p
		by_party[kind] = int(by_party.get(kind, 0)) + int(l["amount"])
	check(unknown.is_empty(), "every ledger line names a known payer or recipient: %s" % str(unknown.slice(0, 5)))
	eq(Payments.unaccounted().size(), 0, "Payments.unaccounted() finds nothing")
	# conservation: a payment between the smith and an adventurer moves the same coins out of / into their purse
	var checked := 0
	var broken := []
	for i in _snaps.size():
		var s: Dictionary = _snaps[i]
		var l2: Dictionary = s["last"]
		var who := str(l2.get("party", ""))
		if l2.is_empty() or not Adv.all().has(who):
			continue
		var amt := int(l2["amount"])
		var now := int((s["purses"] as Dictionary).get(who, 0))
		var before := int((_snaps[i - 1]["purses"] as Dictionary).get(who, now)) if i > 0 else now
		var after := int((_snaps[i + 1]["purses"] as Dictionary).get(who, now)) if i + 1 < _snaps.size() else now
		checked += 1
		if now - before != -amt and after - now != -amt and after - before != -amt:
			broken.append("day %d %+d %s «%s»: purse %d → %d → %d" % [int(l2["day"]), amt, str(l2["cat"]), str(l2["note"]), before, now, after])
	check(checked >= 20, "%d payments between the smith and adventurers were checked" % checked)
	check(broken.is_empty(), "each moved the same coins through the adventurer's purse: %s" % str(broken.slice(0, 5)))
	check(int(by_party.get("village", 0)) >= 0 and int(by_party.get("dev", 0)) == 0, "the village subsidy is its own recorded payer; no developer money in normal play")
	note("60 days: %d ledger lines, %d adventurer payments checked, %d consultations; totals by party %s" % [(Game.state["ledger"] as Array).size(), checked, consults, JSON.stringify(by_party)])


# ------------------------------------------------------------------ 6. consultations
func test_consultation_offers() -> void:
	# a gear-seeker is offered a piece they would buy: "keep your coin" does not come first (PROP-020)
	var probes := 0
	for sd in SEEDS:
		fresh_game("journeyman", sd)
		for def in ["sword_iron", "sword_steel", "helm_iron", "chainmail", "cuirass_iron", "shield_round", "mace_flanged", "axe_hand", "jerkin_leather", "boots_leather", "gloves_leather"]:
			var it := Items.make(def, {"quality": 85.0, "rarity": "common"})
			it["for_sale"] = true
			Game.add_item(it, false)
		for a in Adv.all().values():
			if str(a.get("status", "")) != "in_town" or not Living.has_goal(a, "gear"):
				continue
			var recs := Consult.recommendations(a)
			var buy_i := -1
			var keep_i := -1
			for i in recs.size():
				if str(recs[i]["kind"]) == "buy" and buy_i < 0:
					buy_i = i
				if str(recs[i]["kind"]) == "keep" and keep_i < 0:
					keep_i = i
			if buy_i < 0:
				continue
			probes += 1
			check(int(recs[buy_i]["cost"]) <= int(a["gold"]), "%s: the piece offered is one they can pay for" % a["id"])
			check(keep_i < 0 or keep_i > buy_i, "%s: 'keep your coin' does not come before the purchase (%s)" % [a["id"], str(recs.map(func(r): return "%s %.2f" % [r["kind"], float(r["relevance"])]))])
	check(probes >= 10, "%d gear-seekers had a purchase offer (before S2, 2 of 36 heard 'keep your coin' first)" % probes)
	# the forge's work beyond their purse: the Salt Anvil advice names a real plain piece at the adventurer's price
	fresh_game("apprentice", 4242)
	var a2 := _adv("kestra")
	a2["equipment"].erase("boots")
	a2["equipment"].erase("gloves")
	var star := Items.make("sword_starsteel", {"quality": 80.0})
	star["stats"]["durability"] = int(int(star["stats"]["durability_max"]) * 0.2)
	a2["equipment"]["weapon"] = star
	a2["gold"] = Adv.repair_cost(star) - 1   # the forge's cheapest fix (mending the blade) is just beyond her
	var found := false
	for k in 12:
		Commerce.st()["rival"].erase("stock")
		var ro := Commerce.rival_offer_for(a2)
		if ro.is_empty():
			continue
		for r in Consult.recommendations(a2):
			if str(r["kind"]) == "elsewhere":
				found = true
				eq(int(r["cost"]), int(ro["price"]), "the advice quotes what she would pay at the Salt Anvil (%d g)" % int(r["cost"]))
				check(int(r["cost"]) <= int(a2["gold"]), "and it is within her purse (%d of %d g)" % [int(r["cost"]), int(a2["gold"])])
				check(bool(Commerce.rival_stock()[int(ro["index"])].get("plain", false)), "a plain everyday piece (%s)" % str(ro["item"].get("name", "")))
		if found:
			break
	check(found, "a buyer the forge is too dear for is pointed to a plain piece at the Salt Anvil")
	# a consultation sale: the same piece, its maker and story kept, the payer named
	fresh_game("journeyman", 9001)
	var s := _adv("sigrun")
	s["gold"] = 3000
	s["goals"] = [{"kind": "gear", "since": 1, "target": int(Adv.gear_score(s) * 1.3) + 8}]
	Social.change("sigrun", 80.0, 40.0, "", "", false)
	Consult._cred_add("sigrun", 60.0, 20.0)
	var blade := Items.make("sword_emberwarden", {"quality": 95.0})
	Provenance.set_maker(blade, Provenance.SMITH_ID, "Brannoc Ironhand", "ironhand", "the Ironhand forge")
	blade["for_sale"] = true
	Game.add_item(blade, false)
	var rec := {}
	for r2 in Consult.session("sigrun")["recs"]:
		if str(r2["kind"]) == "buy" and int(r2.get("uid", -1)) == int(blade["uid"]):
			rec = r2
	if not check(not rec.is_empty(), "the blade is offered in the consultation"):
		return
	for sd2 in range(1, 400):
		Game.state["world_seed"] = sd2
		if Consult.roll("sigrun", str(rec["id"])) < 0.3:
			break
	var p0 := int(s["gold"])
	var g0 := Game.gold()
	var res := Consult.advise("sigrun", str(rec["id"]))
	if check(bool(res.get("accepted", false)), "she takes the advice"):
		var worn: Dictionary = s["equipment"][str(rec["slot"])]
		eq(int(worn["uid"]), int(blade["uid"]), "she wears the very piece (same uid)")
		eq(str(Provenance.maker(worn).get("name", "")), "Brannoc Ironhand", "its maker is unchanged")
		eq(Provenance.owner_id(worn), "sigrun", "and she owns it in its chain")
		eq(p0 - int(s["gold"]), Game.gold() - g0, "her purse paid what the smith received (%d g)" % (Game.gold() - g0))
		eq(str(Game.state["ledger"][-1].get("party", "")), "sigrun", "the ledger names her")


# ------------------------------------------------------------------ 7. developer cheats
func test_cheats_off_by_default() -> void:
	fresh_game()
	check(not DevTools.enabled(), "a new game starts with cheats off")
	check(not DevTools.bypass_checks(), "and no skill-check bypass")
	check(not DevTools.indicator_visible(), "no CHEATS ON banner")
	check(not DevTools.used_in(Game.state), "the game is not marked")
	var n0 := Game.inventory().size()
	var g0 := Game.gold()
	check(DevTools.spawn("sword_iron", 1).is_empty() and Game.inventory().size() == n0, "nothing spawns while cheats are off")
	DevTools.add_money(500)
	eq(Game.gold(), g0, "no money appears while cheats are off")
	DevTools.set_bypass(true)
	check(not DevTools.bypass_checks(), "the bypass cannot be switched on while cheats are off")
	check(not DevTools.run_check({"count": 2, "on_done": func(_q: Array): pass}), "a skill check is played normally")
	# switched on: banner, mark, tools, bypass
	DevTools.set_enabled(true)
	check(DevTools.enabled() and DevTools.indicator_visible(), "switched on: the CHEATS ON banner shows")
	check(DevTools.used_in(Game.state), "the running game is marked as played with cheats (%s)" % str(Game.state.get("dev_used", {})))
	check(not DevTools.spawn("sword_iron", 1).is_empty(), "the tools work")
	DevTools.set_bypass(true)
	check(DevTools.bypass_checks(), "the bypass is on")
	check(DevTools.indicator_text().contains("bypass"), "and the banner says so (%s)" % DevTools.indicator_text())
	eq(DevTools.bypass_scores({"count": 3}), [DevTools.BYPASS_QUALITY, DevTools.BYPASS_QUALITY, DevTools.BYPASS_QUALITY], "a 3-round check scores 100 % each round")
	check(DevTools.run_check({"count": 1, "title": "test", "on_done": func(_q: Array): pass}), "the check is bypassed where it starts")
	# never saved: a loaded save starts with cheats off, but keeps the mark
	check(Saves.save("s2_econdev_cheats"), "saved")
	var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(Saves.path("s2_econdev_cheats")))
	var data: Dictionary = doc["data"] if doc is Dictionary else {}
	check(not JSON.stringify(data).contains("\"cheats") and not JSON.stringify(data).contains("bypass"), "the save holds no cheat switch")
	check(DevTools.used_in(data), "but it is marked as made in a game played with cheats")
	check(Saves.load_slot("s2_econdev_cheats"), "loaded")
	Saves.delete("s2_econdev_cheats")
	check(not DevTools.enabled() and not DevTools.bypass_checks() and not DevTools.indicator_visible(), "after a load cheats are off and the banner is gone")
	check(DevTools.used_in(Game.state), "the loaded game is still marked")
	# a new game: off and unmarked
	DevTools.set_enabled(true)
	fresh_game()
	check(not DevTools.enabled() and not DevTools.used_in(Game.state), "a new game: cheats off, no mark")


## The F10 panel: every tool is locked until cheats are switched on; the switch unlocks them.
func test_dev_panel_locked_until_enabled() -> void:
	fresh_game()
	var root := (Engine.get_main_loop() as SceneTree).root
	var host := root.get_child(root.get_child_count() - 1)
	var p := DevPanel.new()
	host.add_child(p)
	var unlocked := []
	var total := 0
	for b in p.body.find_children("*", "BaseButton", true, false):
		total += 1
		if not (b as BaseButton).disabled:
			unlocked.append(str((b as Button).text) if b is Button else str(b.name))
	check(total > 50, "the panel has its tools (%d)" % total)
	check(unlocked.is_empty(), "with cheats off every tool is locked (unlocked: %s)" % str(unlocked))
	var tog := p.find_child("CheatToggle", true, false) as Button
	if check(tog != null, "the cheats switch is there"):
		tog.pressed.emit()
		check(DevTools.enabled() and DevTools.indicator_visible(), "pressing it switches cheats on and shows the banner")
		check(p.find_child("BypassToggle", true, false) != null and not (p.find_child("BypassToggle", true, false) as Button).disabled, "the bypass switch is usable")
		var any_on := false
		for b3 in p.find_children("*", "Button", true, false):
			if (b3 as Button).text == "Crafting: materials, then the forge":
				any_on = not (b3 as Button).disabled
		check(any_on, "the test scenarios are unlocked")
	host.remove_child(p)
	p.free()
	DevTools.end_session()
