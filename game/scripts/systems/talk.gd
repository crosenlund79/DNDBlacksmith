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
	if npc.begins_with("app_") and Game.state.has("apprentices"):   # a workshop apprentice (iteration 012)
		var ap := Apprentices.get_a(npc)
		if not ap.is_empty():
			return str(ap["name"])
	return DB.character(npc).get("name", npc)


static func greeting(npc: String) -> String:
	if npc == Roisin.ID:
		return Roisin.greeting()
	if npc in Commerce.NPCS:   # caravan, pawnshop, rival smith, creature merchants
		return Commerce.greeting(npc)
	var lines: Array = DB.dialogue.get("greet", {}).get(Social.band(npc), ["\"Hm?\""])
	var t: String = lines.pick_random()
	var married := Social.spouse() == npc
	if married:
		t = "\"Husband.\" She smiles despite herself. " + InnLife.married_line(npc)
	if npc == "aldric" and Game.state["world"].get("delivery_pending", false):
		t = "\"Provisions for the forge! Where do you want them?\""
	var a := Adv.get_a(npc)
	if not a.is_empty() and a.get("status") == "injured":
		t += "\n[i](%s is nursing fresh wounds.)[/i]" % a["name"]
	for cu in Shop.waiting():
		if cu["npc"] == npc:
			match str(cu["want"]):
				"dispute":
					t = "\"Your %s failed me out there. I want my money back.\" They hold out the battered piece." % cu.get("item_name", "gear")
				"advice":
					t = "\"%s\"" % str(cu.get("question", "A word about my kit, smith?"))
				"goods":
					t = "\"Have you a %s? I can spend about %d.\"" % [DB.item(cu.get("looking_for", "potion_healing")).get("name", "draught").to_lower(), int(cu.get("budget", 40))]
				"browse":
					if cu.get("looking_for", "") != "":
						t += "\n[i]They are looking for a better %s.[/i]" % cu["looking_for"]
	if Shop.refuses(npc) and not married:
		t += "\n[i]They make it plain they would rather not deal with you.[/i]"
	# village talk about the smith's named pieces (ItemStory) — now and then, at most once a day per person
	if ItemStory.has_rumours() and int(ItemStory.st()["rumours_told"].get(npc, -1)) != Game.day() and npc not in Commerce.NPCS and randf() < 0.35:
		var ru := ItemStory.rumour_line(npc)
		if ru != "":
			t += "\n" + ru
	return t


static func options(npc: String, area: String) -> Array:
	if npc == Roisin.ID:
		return Roisin.options(area)
	var out := []
	var c := DB.character(npc)
	var kind: String = c.get("kind", "hireling")
	out.append({"id": "talk", "label": "Talk"})
	# a counter's keeper: buy from the counter (shown greyed with the reason when the shop is shut)
	var vid := Venues.for_keeper(npc)
	if vid in ["general_store", "herbalist"]:
		var so := {"id": "shop_counter", "label": "Buy from the counter — %s" % ", ".join(Venues.categories(vid).slice(0, 3)).to_lower()}
		if Venues.keeper_away(vid) != "":
			so["disabled"] = "the shop is shut while he delivers"
		elif not Venues.is_open(vid):
			so["disabled"] = "the shop is " + Venues.status_text(vid).to_lower().replace(" — ", "; ")
		out.append(so)
	if not Hire.get_h(npc).is_empty():
		out.append({"id": "manage", "label": "Discuss work and expeditions"})
	if npc == "aldric" and Game.state["world"].get("delivery_pending", false):
		out.insert(0, {"id": "delivery", "label": "Take the weekly delivery"})
	for cu in Shop.waiting():
		if cu["npc"] == npc:
			if cu["want"] == "dispute":
				out.insert(0, {"id": "refund", "label": "Refund them for the %s (%d g)" % [cu.get("item_name", "gear"), int(cu.get("refund", 20))]})
				out.insert(1, {"id": "refuse", "label": "Refuse — the work was sound"})
				continue
			if cu["want"] == "advice":   # The Living Realm 3b (Consult)
				out.insert(0, {"id": "consult", "label": "Hear them out — advise on their gear"})
				out.insert(1, {"id": "send_away", "label": "Ask them to come back another time"})
				continue
			var so2 := {"id": "serve_repair" if cu["want"] == "repair" else "serve", "label": "Take the repair job" if cu["want"] == "repair" else "Show them the wares"}
			if cu["want"] == "repair" and Crafting.station_locked_reason("grinding_wheel") != "":
				so2["disabled"] = "needs your grinding wheel (%s)" % Crafting.station_locked_reason("grinding_wheel").to_lower()
			out.insert(0, so2)
			out.insert(1, {"id": "send_away", "label": "Ask them to come back another time"})
	var a := Adv.get_a(npc)
	if not a.is_empty() and a["status"] in ["in_town", "injured"]:
		out.append({"id": "travels", "label": "Ask about their last expedition"})
		var eo := {"id": "equip", "label": "Give equipment (free)" if Social.spouse() == npc else "Offer equipment"}
		if not Game.inventory().any(func(it): return Items.is_equipment(it)):
			eo["disabled"] = "no equipment in your stores"
		out.append(eo)
		if a.get("needs", "") != "" and not Shop.open_orders().any(func(o): return o["npc"] == npc):
			# Living Workshop #54–55: a commission opportunity — they will place an order if asked (WhoIsWho)
			out.append({"id": "order", "label": "Ask what they need forged — a commission opportunity (%s)" % Shop.slot_phrase(str(a["needs"]))})
		if c.get("romance", false):
			var stage := Social.romance(npc)
			if stage in ["none", "dating"] and Game.hour() >= 17 and area == "inn":
				out.append({"id": "drink", "label": "Share a drink by the fire (4 g)"})
			if InnLife.can_walk(npc):
				out.append({"id": "walk", "label": "Walk her home along the stream"})
			if stage == "dating" and Game.has_flag("walked_" + npc):
				out.append({"id": "court", "label": "Ask to court her"})
			if stage == "courting":
				out.append({"id": "propose", "label": "Propose (offer a silver band)"})
	if npc == "barnaby":   # Ironfront host
		if Ironfront.invite_pending():
			if bool(Ironfront.st().get("intro_heard", false)):
				out.insert(0, {"id": "ironfront_teach", "label": "Yes — teach me (introductory match)"})
			else:
				out.insert(0, {"id": "ironfront_intro", "label": "About your invitation…"})
		out.append({"id": "ironfront_play", "label": "Play a game of Ironfront"})
		out.append({"id": "ironfront_ask", "label": "Ask about Ironfront"})
	if npc == "hilde":
		out.append({"id": "ale", "label": "Buy a round for the room (6 g)"})
		out.append({"id": "meal", "label": "A hot meal by the fire (3 g)"})
	if area == "inn" and (npc == "hilde" or (not a.is_empty() and a["status"] in ["in_town", "injured"])):
		out.append({"id": "tabletalk", "label": "Sit in on the table talk"})
		if npc != "hilde":
			out.append({"id": "dice", "label": "Play knucklebones (5 g a throw)"})
	if kind == "companion":
		out.append({"id": "evening", "label": "Spend the evening (25 g)"})
		out.append({"id": "rumour", "label": "Ask what the adventurers are saying (5 g)"})
	if not a.is_empty() or kind in ["villager", "companion"]:
		var go := {"id": "gift", "label": "Give a small gift (a healing draught)"}
		if Game.count("potion_healing") < 1:
			go["disabled"] = "you have no healing draught"
		out.append(go)
	out.append_array(Commerce.talk_options(npc))
	out.append_array(ItemStory.talk_options(npc))   # "Ask about Wolfbane — its travels"
	if not out.any(func(o): return str(o["id"]) == "consult"):
		out.append_array(Consult.talk_options(npc))   # "Talk about their gear and plans" (The Living Realm 3b)
	out.append({"id": "bye", "label": "Farewell"})
	return out


static func choose(npc: String, opt: String, area: String) -> Dictionary:
	if npc == Roisin.ID:
		var rr := Roisin.choose(opt, area)
		if not rr.is_empty():
			return rr
	var cr := Commerce.talk_choose(npc, opt)
	if not cr.is_empty():
		return cr
	var ir := ItemStory.talk_choose(npc, opt)
	if not ir.is_empty():
		return ir
	var kr := Consult.talk_choose(npc, opt)
	if not kr.is_empty():
		return kr
	var e := Social.ensure(npc)
	var c := DB.character(npc)
	var a := Adv.get_a(npc)
	match opt:
		"shop_counter":
			var sv := Venues.for_keeper(npc)
			if not Venues.is_open(sv):
				return {"text": "\"Shop's shut, smith. %s.\"" % Venues.status_text(sv).replace("Closed — opens", "Opens at")}
			Events.open_panel.emit.call_deferred(str(Venues.get_v(sv)["panel"]), {"id": sv})
			return {"text": "\"What'll it be?\"", "action": "close"}
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
		"ironfront_play":
			Events.open_panel.emit.call_deferred("ironfront", {"id": npc})
			return {"text": "\"Splendid! Helmet on — regulations.\"", "action": "close"}
		"ironfront_ask":
			return {"text": Ironfront.barnaby_lore()}
		"ironfront_intro":
			Ironfront.st()["intro_heard"] = true
			return {"text": Ironfront.intro_text()}
		"ironfront_teach":
			Events.open_panel.emit.call_deferred("ironfront", {"id": npc, "tutorial": true})
			return {"text": "\"Marvellous! Sit, sit. You'll be the Allies — I'll be the Axis, and I'll go gently.\"", "action": "close"}
		"serve":
			return {"text": "", "action": "shop"}
		"refund":
			return {"text": Shop.settle_dispute(npc, true), "action": "close_later"}
		"refuse":
			return {"text": Shop.settle_dispute(npc, false), "action": "close_later"}
		"send_away":
			Shop.dismiss_customer(npc)
			return {"text": "\"Another day, then.\" %s gets up from the bench and heads off." % npc_name(npc), "action": "close_later"}
		"serve_repair":
			return {"text": "You turn the damaged piece over in your hands. Grinding wheel it is.", "action": "repair"}
		"travels":
			Adv.ensure(a)
			var t := Expeditions.tale(npc)
			if t != "":
				Social.change(npc, 1.0, 3.0, "tale_" + str(Game.day()), "Brannoc asked about my last expedition.")
				return {"text": t + "\n\nThey are carrying: " + _gear_text(a)}
			var rep: String = a.get("last_report", "")
			if not a["log"].is_empty() and Social.fam(npc) >= 10.0:
				rep += "\n\n[i]" + "\n".join(a["log"]) + "[/i]"
			if rep == "":
				rep = "\"Haven't been out yet this season. Soon — %s, maybe.\"" % DB.destinations.get(Adv.choose_dest(a.duplicate()), {}).get("name", "the Barrow Fields")
			return {"text": rep + "\n\nThey are carrying: " + _gear_text(a)}
		"equip":
			return {"text": "", "action": "shop"}
		"order":
			var o := Shop.create_order(npc, a["needs"])
			if o.is_empty():
				return {"text": "\"Not from you, smith. Not after last time.\""}
			return {"text": "\"I need a %s — I'd pay %d gold. %s\"" % [Shop.order_text(o), o["reward"], o.get("note", "")]}
		"drink":
			if not Game.can_afford(4):
				return {"text": "Your purse is too light."}
			Game.add_gold(-4, "inn", "Drinks with " + c["name"], "inn")
			if Social.aff(npc) < 20.0:
				Social.change(npc, 2.0, 3.0)
				return {"text": DB.dialogue["romance"]["drink_no"]}
			e["dates"] = int(e.get("dates", 0)) + 1
			Vitality.refresh(5.0)
			Social.change(npc, 7.0, 6.0, "date_" + str(Game.day()), "Shared a quiet drink with Brannoc.")
			if int(e["dates"]) >= 2 and Social.romance(npc) == "none":
				Social.set_romance(npc, "dating")
				Game.journal("You and %s have been seeing each other." % c["name"])
			return {"text": DB.dialogue["romance"]["drink_ok"] + InnLife.maybe_keepsake(npc), "fade": "An hour by the fire…", "minutes": 60}
		"walk":
			return {"text": InnLife.walk(npc), "fade": "The long way home, by the water…", "minutes": 60}
		"meal":
			if not Game.can_afford(3):
				return {"text": "Your purse is too light."}
			Game.add_gold(-3, "inn", "A hot meal at the Wyvern", "inn")
			Vitality.refresh(12.0)
			Social.change("hilde", 1.0, 2.0)
			return {"text": "Hilde sets down mutton stew, black bread and a heel of cheese. \"Eat. You look like a horseshoe somebody forgot in the rain.\"\n[i]You feel a little steadier.[/i]", "fade": "A slow meal by the fire…", "minutes": 30}
		"tabletalk":
			Social.change(npc, 1.0, 2.0)
			var ru2 := ItemStory.rumour_line(npc)
			return {"text": InnLife.table_talk() + (("\n\n" + ru2) if ru2 != "" else "")}
		"dice":
			return {"text": InnLife.knucklebones(npc)}
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
			if Social.aff(npc) < 80.0 or not Game.has_flag("keepsake_" + npc):
				return {"text": DB.dialogue["romance"]["propose_no"]}
			var r := Game.take_uid(int(ring))
			a["equipment"]["ring"] = r
			Social.set_romance(npc, "married")
			Social.change(npc, 15.0, 10.0, "married", "Married Brannoc Ironhand.")
			Game.journal("You married %s. She will keep adventuring — and you will keep her armed." % c["name"])
			Audio.play("sfx/level_up")
			return {"text": DB.dialogue["romance"]["propose_ok"] + "\n\n" + InnLife.wedding(npc), "fade": "A small ceremony at the Chapel of the Dawn…", "minutes": 120}
		"ale":
			if not Game.can_afford(6):
				return {"text": "Your purse is too light."}
			Game.add_gold(-6, "inn", "A round at the Wyvern", "inn")
			Vitality.refresh(4.0)
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
			Game.add_gold(-25, "inn", "An evening at the Velvet Lantern", "lantern")
			Social.change(npc, 3.0, 8.0)
			return {"text": DB.dialogue["lantern"]["evening"] + "\n\n" + _rumour(), "fade": "The night passes discreetly.", "minutes": 180}
		"rumour":
			if not Game.can_afford(5):
				return {"text": "Your purse is too light."}
			Game.add_gold(-5, "inn", "Rumours at the Velvet Lantern", "lantern")
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
