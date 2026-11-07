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
	Shop.customer_hour(h)
	Expeditions.on_hour(h)
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
	if day % 7 == 1:
		Hire.refresh_applicants()
	_social_events()


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
	elif band in ["friendly", "devoted"] and randf() < 0.5:
		Game.state["returns"].append(Loot.make_container("purse_gift", Loot.roll_table("gift", 10.0), "Aldric Pell", "Tucked under the cheese: a little something extra."))
		lines.append("He winks at a small purse tucked under the cheese.")
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
	if Shop.open_orders().size() >= 3 or randf() > 0.4:
		return
	var town := Adv.in_town()
	if town.is_empty():
		return
	var a: Dictionary = town.pick_random()
	if a["needs"] != "" and not Shop.open_orders().any(func(o): return o["npc"] == a["id"]):
		Shop.create_order(a["id"], a["needs"])


static func _social_events() -> void:
	var w: Dictionary = Game.state["world"]
	# a grateful villager or adventurer brings a gift
	for npc in Game.state["social"]:
		var e: Dictionary = Game.state["social"][npc]
		if float(e["aff"]) >= 40.0 and Game.day() - int(e.get("last_gift", -10)) >= 5 and randf() < 0.3:
			var c := DB.character(npc)
			if c.is_empty() or Adv.get_a(npc).get("status", "") in ["dead", "away"]:
				continue
			e["last_gift"] = Game.day()
			Game.state["returns"].append(Loot.make_container("purse_gift", Loot.roll_table("gift", 5.0), c["name"],
				"%s left this at your door with a note: \"For your kindness.\"" % c["name"]))
			Events.toast.emit("%s left a gift at your door." % c["name"], "good")
			Social.remember(npc, "gave_gift_" + str(Game.day()), "Left the smith a gift", 2.0)
			break
	# a friend back from the road shares what they learned (scouting knowledge for everyone)
	for a in Adv.in_town():
		if Social.band(a["id"]) in ["friendly", "devoted"] and not a.get("history", []).is_empty() and randf() < 0.25:
			var dest: String = a["history"][-1]["dest"]
			if Regions.scouted(dest) < Regions.SCOUT_MAX - 5.0:
				Regions.add_scouting(dest, 6.0, "told by " + a["name"])
				Events.toast.emit("%s told you the safe paths through %s." % [a["name"], DB.destinations[dest]["name"]], "good")
				break
	# deep gratitude: a devoted friend brings something old and strange from the barrows
	for npc in Game.state["social"]:
		if Social.band(npc) == "devoted" and not Social.has_memory(npc, "gave_relic") and randf() < 0.35:
			var c2 := DB.character(npc)
			if c2.is_empty() or Adv.get_a(npc).get("status", "") in ["dead", "away"]:
				continue
			Social.remember(npc, "gave_relic", "Gave the smith a relic out of gratitude", 4.0)
			Game.state["returns"].append(Loot.make_container("satchel_relic", Loot.roll_table("gratitude"), c2["name"],
				"%s left this with a note: \"Found it in the barrows. I trust you more than any collector.\"" % c2["name"]))
			Events.toast.emit("%s left you a relic in gratitude." % c2["name"], "good")
			Events.inventory_changed.emit()
			break
	# a dissatisfied villager pelts the storefront with eggs
	if not w.get("eggs", false):
		for npc in Game.state["social"]:
			if float(Game.state["social"][npc]["aff"]) <= -30.0 and randf() < 0.45:
				w["eggs"] = true
				w["eggs_by"] = npc
				Events.toast.emit("Someone pelted your storefront with eggs overnight.", "bad")
				Events.world_flag_changed.emit("eggs")
				Game.journal("Eggs on the shop front. Whispers say it was %s." % DB.character(npc).get("name", npc))
				break
	# gossip: the worst memory of a sour customer spreads to a friend
	for npc in Game.state["social"]:
		var m := Social.strongest_memory(npc)
		if not m.is_empty() and float(m["w"]) <= -10.0 and randf() < 0.3 and not Social.has_memory("pip", "gossip_" + npc):
			Social.change("pip", -3.0, 1.0, "gossip_" + npc, "Heard from %s: \"%s\"" % [DB.character(npc).get("name", npc), m["text"]], false)
			Social.change("wenna", -2.0, 1.0, "", "", false)
			break


static func clean_eggs() -> void:
	Game.state["world"]["eggs"] = false
	Game.journal("Scrubbed the eggs off the shop front.")
	Events.world_flag_changed.emit("eggs")
