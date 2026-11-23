## Sim — the world keeps living: hourly and daily simulation, the grocer's weekly visit,
## village social events and the Mira/Aldric story chain.
## EN: Called by Game's clock. Never depends on the player's position, so the village carries on
##     whether or not the player watches.
## DA: Kaldes af Game-uret. Afhænger aldrig af spillerens position, så landsbyen lever videre,
##     uanset om spilleren ser på.
class_name Sim
extends RefCounted


static func on_hour(_day: int, h: int) -> void:
	Hire.work_hour(h)
	Vitality.on_hour()
	Shop.customer_hour(h)
	Consult.on_hour(h)   # The Living Realm 3b: adventurers come for equipment advice; past advice is judged
	Expeditions.on_hour(h)
	HealthLog.on_hour(h)   # Living Workshop #38: adventurers' health over time, from real values only
	Trade.on_hour(h)
	Commerce.on_hour(h)
	Apprentices.on_hour(h)
	if h == 9:
		_grocer_check()
	if h == 15 and Game.day() == 1 and not Game.has_flag("aldric_asked"):
		_aldric_asks()
	if h == 10:
		_maybe_order()


static func on_day(day: int) -> void:
	Hire.on_day()
	Adv.on_day()
	Shop.expire_orders()
	Shop.pay_upkeep()
	Shop.expire_offers()
	Trade.on_day()
	Commerce.on_day()
	Ironfront.on_day()   # v1.7: adventurers sell the painted cards they found on the road to Barnaby
	ItemStory.on_day()   # earned names, fame commissions, the circulating pool
	Apprentices.on_day()   # apprentice wages, loyalty, upkeep, independence, weekly applicants
	Contracts.on_day()   # The Living Realm: patrons' letters, deadlines of major contracts
	Sponsor.settle_debts()   # Run 0.1 (D14): what is still owed to a sponsored company is paid as coin allows
	if day % 7 == 1:
		Hire.refresh_applicants()
	_social_events()
	Lore.on_day(day)   # R3: routine workshop work older than two months folds into monthly digests
	Institutions.on_day(day)   # R4: the village purse takes in its weekly income


# ------------------------------------------------------------------ grocer
static func _grocer_check() -> void:
	var week := int((Game.day() - 1) / 7)
	var due := Game.day() == 3 or (Game.day() % 7 == 0)
	if due and int(Game.state["world"].get("last_delivery_day", 0)) != Game.day():
		Game.state["world"]["delivery_pending"] = true
		Game.state["world"]["last_delivery_day"] = Game.day()
		Events.toast.emit("Aldric the grocer is at your door with the weekly provisions.", "info")
		Events.world_flag_changed.emit("delivery")
	var _w := week


## The player accepts the delivery (talking to Aldric while delivery_pending).
static func take_delivery() -> String:
	Game.state["world"]["delivery_pending"] = false
	var band := Social.band("aldric")
	var lines := []
	match band:
		"hostile", "cool":
			Game.add_item(Items.make("bread_cheese", {"qty": 1}), false)
			lines.append("He sets down a single stale loaf and a wedge of sweating cheese. \"That's what's left.\"")
		"neutral":
			Game.add_item(Items.make("bread_cheese", {"qty": 3}), false)
			lines.append("Bread, cheese, onions and a jar of pickled eggs. \"Same as always, smith.\"")
		_:
			Game.add_item(Items.make("bread_cheese", {"qty": 4}), false)
			lines.append("The good bread, still warm, a ham hock and a crock of honey. \"Picked the best for you.\"")
			Game.add_item(Items.make("herb_moonwort", {"qty": 2}), false)
	if Social.has_memory("aldric", "kin_equip_mira_good") and not Social.has_memory("aldric", "gave_runestone"):
		Game.add_item(Items.make("runestone_ember"), false)
		Social.remember("aldric", "gave_runestone", "Gave the smith a runestone", 5.0)
		lines.append("\"A traveller paid me with this odd stone. Mira says you'd know what to do with it. Take it — for looking after my girl.\"")
	elif band in ["friendly", "devoted"] and Rng.f("world") < 0.5:
		var purse := gift_of("aldric")   # R2: from his own counter's stock
		if not purse.get("items", []).is_empty():
			Game.state["returns"].append(Loot.make_container("purse_gift", purse["items"], "Aldric Pell", "Tucked under the cheese: a little something extra from his own shelves."))
			lines.append("He winks at a small bundle tucked under the cheese.")
			Events.inventory_changed.emit()   # world redraws the waiting bags
	elif Social.has_memory("aldric", "kin_gear_failed_mira") or Social.has_memory("aldric", "blame_mira"):
		lines.append("He doesn't meet your eye. \"Mira came home with a broken bow-arm. Your gear, I hear.\"")
	Social.change("aldric", 1.0, 3.0)
	Audio.play("sfx/bag_open")
	return "\n".join(lines)


static func _aldric_asks() -> void:
	Game.set_flag("aldric_asked")
	var o := Shop.create_order("mira", "weapon", "Aldric: \"She leaves for the Barrow Fields on the third day. Please — something that won't snap.\"")
	if not o.is_empty():
		o["deadline"] = 3
	Social.remember("aldric", "asked_for_mira", "Asked the smith to equip Mira", 0.0)
	Events.toast.emit("Aldric came by: Mira needs a proper blade before the Barrow Fields.", "info")


static func on_mira_equipped(it: Dictionary, price: int) -> void:
	var good: bool = float(it.get("quality", 70)) >= 80.0 or it.get("rarity") in ["rare", "legendary", "unique", "set"]
	if good:
		Social.change("mira", 6.0, 4.0, "equip_mira_good", "Equipped Mira with fine work (%s)." % it["name"])
	if price == 0:
		Social.change("aldric", 8.0, 3.0, "mira_free_gear", "Gave Mira gear without charging her.", false)


static func on_mira_returned(success: bool, mine: Array) -> void:
	if success and not mine.is_empty():
		Social.change("aldric", 10.0, 4.0, "mira_safe", "Mira came home safe, swinging the smith's blade.", false)
	elif not success:
		Social.change("aldric", -4.0, 2.0, "mira_hurt", "Mira came home hurt.", false)


# ------------------------------------------------------------------ orders & social events
static func _maybe_order() -> void:
	if Shop.open_orders().size() >= 3 or Rng.f("world") > 0.4:
		return
	var town := Adv.in_town()
	if town.is_empty():
		return
	var a: Dictionary = Rng.pick("world", town)
	if a["needs"] != "" and not Shop.open_orders().any(func(o): return o["npc"] == a["id"]):
		Shop.create_order(a["id"], Adv.request_slot(a, str(a["needs"])))   # A2: weighted toward what the forge can make


## A thank-you gift from `npc` (the "gift" loot table), worth at most their gift budget (Payments.gift_budget: half of
## what they paid the forge in the last 30 days, less earlier gifts). [] when nothing fits — no gift then.
## Milestone A2: before, every gift was an unbounded roll (118 g on average, up to 1,600 g) whatever the giver had
## spent — three in a few days could be worth several times the purchase that warmed them to the smith.
## R2 (ECO-045, canonical §1.2): a gift comes out of what the giver really has — never rolled from a loot table.
##   an adventurer: a piece from their own pack (spares they carry, kit they replaced; for a "relic" gift only a relic
##     they hold), else a little of their own coin;
##   a shopkeeper: something from their own counter's stock today (Aldric's provisions, the herbalist's shelves), which
##     then is no longer for sale;
##   anyone else: no gift — they have nothing simulated to give.
## Still bounded by A2's budget (half their business with the forge this month, less earlier gifts). Returns
## {items: [...]} or {gold: n} (paid at once, from their purse to the smith's) or {} when nothing fits.
const KEEPER_STORE := {"aldric": "general_store", "herbalist": "herbalist"}


static func gift_of(npc: String, relic_only := false, items_only := false, cap_override := -1) -> Dictionary:
	var cap := Payments.gift_budget(npc) if cap_override < 0 else cap_override
	if cap <= 0:
		return {}
	var a := Adv.get_a(npc)
	if not a.is_empty():
		var best := {}
		var best_v := -1
		for it in a.get("loot", []):
			if not (it is Dictionary) or (it as Dictionary).is_empty():
				continue
			if relic_only and not (Regions.is_unidentified(it) or Items.def(it).get("tags", []).has("relic") or str(Items.def(it).get("type", "")) == "relic"):
				continue
			var v := Items.value(it)
			if v <= cap and v > best_v:
				best = it
				best_v = v
		if not best.is_empty():
			(a["loot"] as Array).erase(best)
			best["_arrives_how"] = "given"
			Payments.note_gift(npc, best_v)
			return {"items": [best]}
		if relic_only or items_only:
			return {}
		var coins := mini(cap, int(int(a.get("gold", 0)) * 0.2))
		if coins >= 5:
			a["gold"] = int(a["gold"]) - coins
			Payments.note_gift(npc, coins)
			Game.add_gold(coins, "gift", "A gift from %s" % str(a.get("name", npc)), npc)
			return {"gold": coins}
		return {}
	var store := str(KEEPER_STORE.get(npc, ""))
	if store == "" or relic_only:
		return {}
	var pick := {}
	var pick_v := -1
	for e in Trade.store_stock(store):
		if int(e.get("qty", 0)) < 1:
			continue
		var uv := Commerce.unit_value(Items.make(str(e["def"]), {"qty": 1}))
		if uv <= cap and uv > pick_v:
			pick = e
			pick_v = uv
	if pick.is_empty():
		return {}
	var n := clampi(int(cap / maxi(1, pick_v)), 1, mini(2, int(pick["qty"])))
	pick["qty"] = int(pick["qty"]) - n
	Payments.note_gift(npc, pick_v * n)
	return {"items": [Items.make(str(pick["def"]), {"qty": n})]}


static func _social_events() -> void:
	var w: Dictionary = Game.state["world"]
	# a grateful villager or adventurer brings a gift
	for npc in Game.state["social"]:
		var e: Dictionary = Game.state["social"][npc]
		if float(e["aff"]) >= 40.0 and Game.day() - int(e.get("last_gift", -10)) >= 5 and Rng.f("world") < 0.3:
			var c := DB.character(npc)
			if c.is_empty() or Adv.get_a(npc).get("status", "") in ["dead", "away"]:
				continue
			var gift := gift_of(str(npc))
			if gift.is_empty():
				continue   # nothing of their own within what their dealings with the forge warrant
			e["last_gift"] = Game.day()
			if gift.has("gold"):
				Events.toast.emit("%s left %d gold at your door: \"For your kindness.\"" % [c["name"], int(gift["gold"])], "good")
			else:
				Game.state["returns"].append(Loot.make_container("purse_gift", gift["items"], c["name"],
					"%s left this at your door with a note: \"For your kindness.\"" % c["name"]))
				Events.toast.emit("%s left a gift at your door." % c["name"], "good")
			Social.remember(npc, "gave_gift_" + str(Game.day()), "Left the smith a gift", 2.0)
			break
	# a friend back from the road shares what they learned (scouting knowledge for everyone)
	for a in Adv.in_town():
		if Social.band(a["id"]) in ["friendly", "devoted"] and not a.get("history", []).is_empty() and Rng.f("world") < 0.25:
			var dest: String = a["history"][-1]["dest"]
			if Regions.scouted(dest) < Regions.SCOUT_MAX - 5.0:
				Regions.add_scouting(dest, 6.0, "told by " + a["name"])
				Events.toast.emit("%s told you the safe paths through %s." % [a["name"], DB.destinations[dest]["name"]], "good")
				break
	# deep gratitude: a devoted friend brings something old and strange from the barrows — S2 (BUG-045): bounded like
	# every other gift (Sim.gift_of: at most half their business with the forge this month, less earlier gifts); when
	# nothing fits there is no relic yet, and they may bring one later (before, the satchel bypassed the cap)
	for npc in Game.state["social"]:
		if Social.band(npc) == "devoted" and not Social.has_memory(npc, "gave_relic") and Rng.f("world") < 0.35:
			var c2 := DB.character(npc)
			if c2.is_empty() or Adv.get_a(npc).get("status", "") in ["dead", "away"]:
				continue
			var relic: Array = gift_of(str(npc), true).get("items", [])   # R2: only a relic they really carry
			if relic.is_empty():
				continue
			Social.remember(npc, "gave_relic", "Gave the smith a relic out of gratitude", 4.0)
			Game.state["returns"].append(Loot.make_container("satchel_relic", relic, c2["name"],
				"%s left this with a note: \"Brought it home from the road. I trust you more than any collector.\"" % c2["name"]))
			Events.toast.emit("%s left you a relic in gratitude." % c2["name"], "good")
			Events.inventory_changed.emit()
			break
	# a dissatisfied villager pelts the storefront with eggs
	if not w.get("eggs", false):
		for npc in Game.state["social"]:
			if float(Game.state["social"][npc]["aff"]) <= -30.0 and Rng.f("world") < 0.45:
				w["eggs"] = true
				w["eggs_by"] = npc
				Events.toast.emit("Someone pelted your storefront with eggs overnight.", "bad")
				Events.world_flag_changed.emit("eggs")
				Game.journal("Eggs on the shop front. Whispers say it was %s." % DB.character(npc).get("name", npc))
				break
	# gossip: the worst memory of a sour customer spreads to a friend
	for npc in Game.state["social"]:
		var m := Social.strongest_memory(npc)
		if not m.is_empty() and float(m["w"]) <= -10.0 and Rng.f("world") < 0.3 and not Social.has_memory("pip", "gossip_" + npc):
			Social.change("pip", -3.0, 1.0, "gossip_" + npc, "Heard from %s: \"%s\"" % [DB.character(npc).get("name", npc), m["text"]], false)
			Social.change("wenna", -2.0, 1.0, "", "", false)
			break


static func clean_eggs() -> void:
	Game.state["world"]["eggs"] = false
	Game.journal("Scrubbed the eggs off the shop front.")
	Events.world_flag_changed.emit("eggs")
