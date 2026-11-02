## Talk — context-sensitive dialogue options and their consequences.
## EN: Builds the option list for an NPC from who they are, where you are, the time of day and your
##     shared history; resolves the chosen option (social changes, romance, deliveries, rumours…).
##     Returns {text, action} where action may ask the UI to open another panel.
## DA: Bygger svarmulighederne for en person ud fra hvem de er, hvor du er, tidspunktet og jeres
##     fælles historie; udfører det valgte (sociale ændringer, romantik, leverancer, rygter…).
class_name Talk
extends RefCounted


static func npc_name(npc: String) -> String:
	var h := Hire.get_h(npc)
	if not h.is_empty():
		return h["name"]
	return DB.character(npc).get("name", npc)


static func greeting(npc: String) -> String:
	var lines: Array = DB.dialogue.get("greet", {}).get(Social.band(npc), ["\"Hm?\""])
	var t: String = lines.pick_random()
	var married := Social.spouse() == npc
	if married:
		t = "\"Husband.\" She smiles despite herself."
	if npc == "aldric" and Game.state["world"].get("delivery_pending", false):
		t = "\"Provisions for the forge! Where do you want them?\""
	var a := Adv.get_a(npc)
	if not a.is_empty() and a.get("status") == "injured":
		t += "\n[i](%s is nursing fresh wounds.)[/i]" % a["name"]
	return t


static func options(npc: String, area: String) -> Array:
	var out := []
	var c := DB.character(npc)
	var kind: String = c.get("kind", "hireling")
	out.append({"id": "talk", "label": "Talk"})
	if not Hire.get_h(npc).is_empty():
		out.append({"id": "manage", "label": "Discuss work and expeditions"})
	if npc == "aldric" and Game.state["world"].get("delivery_pending", false):
		out.insert(0, {"id": "delivery", "label": "Take the weekly delivery"})
	for cu in Shop.customers():
		if cu["npc"] == npc:
			out.insert(0, {"id": "serve_repair" if cu["want"] == "repair" else "serve", "label": "Take the repair job" if cu["want"] == "repair" else "Serve at the counter"})
	var a := Adv.get_a(npc)
	if not a.is_empty() and a["status"] in ["in_town", "injured"]:
		out.append({"id": "travels", "label": "Ask about their travels"})
		out.append({"id": "equip", "label": "Give equipment (free)" if Social.spouse() == npc else "Offer equipment"})
		if a.get("needs", "") != "" and not Shop.open_orders().any(func(o): return o["npc"] == npc):
			out.append({"id": "order", "label": "Ask what they need forged"})
		if c.get("romance", false):
			var stage := Social.romance(npc)
			if stage in ["none", "dating"] and Game.hour() >= 17 and area == "inn":
				out.append({"id": "drink", "label": "Share a drink by the fire (4 g)"})
			if stage == "dating":
				out.append({"id": "court", "label": "Ask to court her"})
			if stage == "courting":
				out.append({"id": "propose", "label": "Propose (offer a silver band)"})
	if npc == "hilde":
		out.append({"id": "ale", "label": "Buy a round for the room (6 g)"})
	if kind == "companion":
		out.append({"id": "evening", "label": "Spend the evening (25 g)"})
		out.append({"id": "rumour", "label": "Ask what the adventurers are saying (5 g)"})
	if not a.is_empty() or kind in ["villager", "companion"]:
		out.append({"id": "gift", "label": "Give a small gift (a healing draught)"})
	out.append({"id": "bye", "label": "Farewell"})
	return out


static func choose(npc: String, opt: String, area: String) -> Dictionary:
	var e := Social.ensure(npc)
	var c := DB.character(npc)
	var a := Adv.get_a(npc)
	match opt:
		"talk":
			var first_today := int(e.get("last_talk", -1)) != Game.day()
			e["last_talk"] = Game.day()
			if first_today:
				Social.change(npc, 1.5 if Social.band(npc) != "hostile" else 0.0, 4.0)
			if npc == "borin":
				Objectives.complete("talk_borin")
			if not a.is_empty() and area == "inn":
				Objectives.complete("visit_inn")
			return {"text": _story(npc)}
		"manage":
			return {"text": "\"Right then, boss. Where do you want me?\"", "action": "hirelings"}
		"delivery":
			return {"text": Sim.take_delivery()}
		"serve":
			return {"text": "", "action": "shop"}
		"serve_repair":
			return {"text": "You turn the damaged piece over in your hands. Grinding wheel it is.", "action": "repair"}
		"travels":
			var rep: String = a.get("last_report", "")
			if rep == "":
				rep = "\"Haven't been out yet this season. Soon — %s, maybe.\"" % DB.destinations.get(Adv.choose_dest(a.duplicate()), {}).get("name", "the Barrow Fields")
			return {"text": rep + "\n\nThey are carrying: " + _gear_text(a)}
		"equip":
			return {"text": "", "action": "shop"}
		"order":
			var o := Shop.create_order(npc, a["needs"])
			return {"text": "\"Something for my %s — I'd pay %d gold for %s %d or better.\"" % [o["slot"], o["reward"], o["stat"], o["min"]]}
		"drink":
			if not Game.can_afford(4):
				return {"text": "Your purse is too light."}
			Game.add_gold(-4, "inn", "Drinks with " + c["name"])
			if Social.aff(npc) < 20.0:
				Social.change(npc, 2.0, 3.0)
				return {"text": DB.dialogue["romance"]["drink_no"]}
			e["dates"] = int(e.get("dates", 0)) + 1
			Social.change(npc, 7.0, 6.0, "date_" + str(Game.day()), "Shared a quiet drink with Brannoc.")
			if int(e["dates"]) >= 2 and Social.romance(npc) == "none":
				Social.set_romance(npc, "dating")
			return {"text": DB.dialogue["romance"]["drink_ok"], "fade": "An hour by the fire…", "minutes": 60}
		"court":
			if Social.aff(npc) >= 55.0:
				Social.set_romance(npc, "courting")
				Social.change(npc, 6.0, 4.0, "courting", "Brannoc asked to court me.")
				return {"text": DB.dialogue["romance"]["court_ok"]}
			return {"text": "\"Slow down, old man. I like you — give it time.\""}
		"propose":
			var ring := ""
			for it in Game.inventory():
				if Items.slot(it) == "ring":
					ring = str(it["uid"])
					break
			if ring == "":
				return {"text": "You'll need a ring. A silver band from your own anvil would be fitting."}
			if Social.aff(npc) < 80.0:
				return {"text": DB.dialogue["romance"]["propose_no"]}
			var r := Game.take_uid(int(ring))
			a["equipment"]["ring"] = r
			Social.set_romance(npc, "married")
			Social.change(npc, 15.0, 10.0, "married", "Married Brannoc Ironhand.")
			Game.journal("You married %s. She will keep adventuring — and you will keep her armed." % c["name"])
			Audio.play("sfx/level_up")
			return {"text": DB.dialogue["romance"]["propose_ok"], "fade": "A small ceremony at the Chapel of the Dawn…", "minutes": 120}
		"ale":
			if not Game.can_afford(6):
				return {"text": "Your purse is too light."}
			Game.add_gold(-6, "inn", "A round at the Wyvern")
			for ad in Adv.in_town():
				Social.change(ad["id"], 2.0, 3.0)
			Social.change("hilde", 2.0, 2.0)
			return {"text": "Cheers ring out across the common room. \"To the smith!\""}
		"evening":
			var h := Game.hour()
			if not (h >= 19 or h < 2):
				return {"text": DB.dialogue["lantern"]["closed"]}
			if not Game.can_afford(25):
				return {"text": "Your purse is too light."}
			Game.add_gold(-25, "inn", "An evening at the Velvet Lantern")
			Social.change(npc, 3.0, 8.0)
			return {"text": DB.dialogue["lantern"]["evening"] + "\n\n" + _rumour(), "fade": "The night passes discreetly.", "minutes": 180}
		"rumour":
			if not Game.can_afford(5):
				return {"text": "Your purse is too light."}
			Game.add_gold(-5, "inn", "Rumours at the Velvet Lantern")
			return {"text": _rumour()}
		"gift":
			if Game.count("potion_healing") < 1:
				return {"text": "You have no healing draught to give."}
			Game.remove_def("potion_healing", 1)
			e["last_gift_given"] = Game.day()
			Social.change(npc, 6.0, 3.0, "gift_" + str(Game.day()), "Brannoc gave me a healing draught.")
			return {"text": "\"For me? That's... thoughtful. Thank you.\""}
	return {"text": "", "action": "close"}


static func _story(npc: String) -> String:
	var stories: Array = DB.dialogue.get("stories", {}).get(npc, [])
	var e := Social.ensure(npc)
	var told: int = int(e.get("stories_told", 0))
	var avail := stories.filter(func(s): return float(s[0]) <= Social.fam(npc))
	var text := greeting(npc)
	if told < avail.size():
		text += "\n\n" + str(avail[told][1])
		e["stories_told"] = told + 1
	else:
		var m := Social.strongest_memory(npc)
		if not m.is_empty() and Social.band(npc) != "neutral":
			text += "\n\n[i]%s[/i]" % ("They still talk about it: " + str(m["text"]))
	return text


static func _rumour() -> String:
	var pool := Adv.all().values().filter(func(x): return x["status"] in ["in_town", "away"])
	if pool.is_empty():
		return "\"Quiet week. Nobody's saying much.\""
	var a: Dictionary = pool.pick_random()
	var dest: String = DB.destinations.get(a.get("dest", ""), {}).get("name", "the Barrow Fields")
	Game.set_flag("rumour_" + a["id"])
	var t: String = DB.dialogue["rumours"].pick_random()
	return t.replace("{adv}", a["name"]).replace("{dest}", dest)


static func _gear_text(a: Dictionary) -> String:
	var parts := []
	for s in a["equipment"]:
		parts.append(Items.display_name(a["equipment"][s]))
	return ", ".join(parts) if not parts.is_empty() else "nothing worth mentioning"
