## ItemStory — what the world makes of a piece once it leaves the anvil (iteration 011, "The World Remembers").
## EN: Builds on Lore (the one event registry) and Provenance (each piece's identity):
##     • Names earned through history: a boss slain, an owner who survived death again and again, a famous owner,
##       many campaigns, or (optionally) extraordinary craftsmanship. Deterministic, authored patterns that name the
##       real enemy, owner or place. A name is recorded once as a `named` Lore event and is never re-rolled.
##     • Famous creations: the smith's named and Epic pieces, their deeds and current owner (Hall of Fame).
##     • Rumours (greetings, table talk), village reactions (toasts, Chronicle) and special commissions
##       ("a blade like Wolfbane") through Shop.create_order.
##     • "A Familiar Creation": when one of the smith's pieces comes back to the workshop (a repair customer, an offer
##       at the counter, a recovered chest, a buy-back, an adventurer showing it), each significant reunion is
##       acknowledged ONCE — stored in Provenance.st(it)["reunions"] keyed by occasion and owner.
##     • Workshop services that add history: sharpening (grinding wheel) and reforging (forge + anvil). Maker,
##       uid and name are always kept; every service is a Provenance.workshop event.
##     • A circulating pool: the smith's pieces that have left the known world (buried, lost, sold on) are
##       remembered as light snapshots, so that now and then a stranger walks in with an old Ironhand blade.
##     State: Game.state["item_story"] = {famous:{uid:{…}}, pool:{uid:item}, fame_orders:{uid:order id},
##     pending_fame:[uid], stranger_day:int, rumours_told:{npc:day}} — created lazily (old saves load).
## DA: Navne fortjent gennem historie, berømte værker, rygter, særlige bestillinger, gensyn med egne værker
##     ("En kendt skabelse") og værkstedsydelser (slibning, omsmedning), alt sammen bygget på Lore og Provenance.
class_name ItemStory
extends RefCounted

const SURVIVAL_N := 3        # near-deaths survived by an owner wearing it -> "Last Breath"
const CAMPAIGN_N := 8        # expeditions carried on -> "Old Faithful"
const FAME_REWARD := 40      # extra pay on a commission inspired by a famous piece
const STRANGER_CHANCE := 0.06
const STRANGER_GAP := 6      # days between strangers with old blades
const POOL_CAP := 40
const PLAIN_REUNION_DAYS := 14   # a plain piece is recognised when it has aged this long or changed hands twice

## Boss-kill name patterns per foe kind: [bane, breaker-pattern, bane-of pattern] — picked by the piece's uid.
const BANE := {"beast": "Wolfbane", "spider": "Webcutter", "humanoid": "Tollbreaker", "spirit": "Shadowsunder",
	"undead": "Gravebane", "construct": "Stonesplitter", "dragon": "Wyrmbane"}
const OWNER_FORMS := {"weapon": "%s's Oath", "shield": "%s's Wall", "armor": "%s's Mantle", "helmet": "%s's Crown",
	"gloves": "%s's Grip", "boots": "%s's Stride", "belt": "%s's Girdle", "ring": "%s's Promise", "amulet": "%s's Keepsake"}
const MASTER_NAMES := ["Ironhand's Pride", "Brindlewick's Pride", "the Hearth-Born"]
const ORDINALS := ["", " the Second", " the Third", " the Fourth", " the Fifth"]

## History-row icon per Lore kind (ui/story_<kind>, drawn by tools/art/make_itemstory_art.py).
const STORY_ICON := {"forged": "forged", "sold": "sale", "bought": "sale", "given": "sale", "pawned": "sale", "redeemed": "sale",
	"found": "found", "looted": "found", "inherited": "inherited", "recovered": "inherited", "repaired": "repaired",
	"reforged": "reforged", "enchanted": "enchanted", "treated": "treated", "sharpened": "sharpened", "battle": "battle",
	"slew": "battle", "victory": "battle", "survived": "survived", "discovery": "discovery", "cleared": "discovery",
	"named": "named", "epic": "epic", "lost": "lost", "destroyed": "lost", "death": "lost", "returned": "reunion",
	"reunion": "reunion", "commission": "commission", "commissioned": "commission", "note": "note", "received": "found", "offered": "found"}
const MARK_TEX := "marks/"


# ======================================================================= state
static func st() -> Dictionary:
	if not Game.state.has("item_story"):
		Game.state["item_story"] = {"famous": {}, "pool": {}, "fame_orders": {}, "pending_fame": [], "stranger_day": -99, "rumours_told": {}}
	var s: Dictionary = Game.state["item_story"]
	for k in ["famous", "pool", "fame_orders", "rumours_told"]:
		if not s.has(k):
			s[k] = {}
	if not s.has("pending_fame"):
		s["pending_fame"] = []
	return s


static func story_icon(kind: String) -> String:
	return "ui/story_" + str(STORY_ICON.get(kind, "note"))


static func mark_icon(it: Dictionary) -> String:
	return MARK_TEX + str(Provenance.maker(it).get("mark", "unknown"))


## An item instance anywhere the smith can see it (stores, worn, adventurers, hirelings, offers, customers).
static func find(uid: int) -> Dictionary:
	if uid <= 0:
		return {}
	var it := History.find_item(uid)
	if not it.is_empty():
		return it
	for c2 in Shop.customers():
		if int(c2.get("item", {}).get("uid", -1)) == uid:
			return c2["item"]
	return {}


## A place id as people name it.
static func place_name(id: String) -> String:
	if id == "" :
		return ""
	if id == "brindlewick":
		return "Brindlewick"
	var r := Expeditions.region(id)
	if not r.is_empty():
		return str(r.get("name", id))
	var d: Dictionary = DB.destinations.get(id, {})
	if not d.is_empty():
		return str(d.get("name", id))
	return id.replace("_", " ").capitalize()


## Is the World worker's map in this build? (Place links open it; without it they stay plain text.)
static func has_world_map() -> bool:
	return ResourceLoader.exists("res://scripts/systems/world_map.gd") or ResourceLoader.exists("res://scripts/ui/panels/world_map_panel.gd")


# ======================================================================= names earned through history
static func is_named(it: Dictionary) -> bool:
	return it.has("named") or it.has("title")


static func earned_name(it: Dictionary) -> String:
	if it.has("named"):
		return str(it["named"].get("name", ""))
	return str(it.get("title", ""))


## Can this piece earn a name? The smith's own work, or anything already exceptional.
static func can_be_named(it: Dictionary) -> bool:
	if it.is_empty() or not Items.is_equipment(it):
		return false
	return Provenance.is_mine(it) or str(it.get("rarity", "")) in ["rare", "legendary", "unique", "set"]


static func _name_taken(n: String) -> bool:
	for k in st()["famous"]:
		if str(st()["famous"][k].get("name", "")) == n:
			return true
	return false


## Never two pieces of the same name: a second "Wolfbane" becomes "Wolfbane the Second".
static func _unique(n: String) -> String:
	for o in ORDINALS:
		if not _name_taken(n + o):
			return n + o
	return "%s of Day %d" % [n, Game.day()]


## A deterministic choice among authored forms (the piece's uid decides; never random, never re-rolled).
static func _pick(it: Dictionary, forms: Array) -> String:
	return str(forms[absi(int(it.get("uid", 0))) % forms.size()])


## The boss's distinctive word: "The Toll Troll" -> "Toll", "Grimfang the Old" -> "Grimfang".
static func _boss_word(boss: String) -> String:
	var b := boss.strip_edges()
	if b.to_lower().begins_with("the "):
		b = b.substr(4)
	var w := b.split(" ", false)
	return str(w[0]).capitalize() if not w.is_empty() else "Beast"


## The boss-kill name: one of three authored forms that names the real foe.
static func bane_name(it: Dictionary, boss: String, foe_kind: String) -> String:
	var kind := "spider" if boss.contains("Brood") or boss.to_lower().contains("spider") else foe_kind
	var bane := str(BANE.get(kind, "Banebringer"))
	var word := _boss_word(boss)
	var b := boss.strip_edges()
	if not b.to_lower().begins_with("the ") and b.split(" ", false).size() > 1:
		b = "the " + b
	elif b.to_lower().begins_with("the "):
		b = "the " + b.substr(4)
	return _pick(it, [bane, "the %s-Breaker" % word, "Bane of %s" % b])


## Gives a piece its earned name. Returns false if it already has one (names are never re-rolled).
## kind: boss | survival | owner | campaigns | masterwork. refs: adv, place, enemy.
static func name_item(it: Dictionary, nm: String, kind: String, why: String, refs := {}) -> bool:
	if not can_be_named(it) or is_named(it):
		return false
	var final_name := _unique(nm)
	var base := str(it.get("name", ""))
	var adv := str(refs.get("adv", ""))
	var place := str(refs.get("place", ""))
	it["named"] = {"name": final_name, "kind": kind, "why": why, "day": Game.day(), "adv": adv, "place": place,
		"enemy": str(refs.get("enemy", "")), "base": base}
	it["title"] = final_name          # read by Provenance.is_notable and the older tooltip line
	it["base_name"] = base
	it["name"] = final_name
	var ev := Lore.record("named", "%s was named “%s” — %s." % [base, final_name, why],
		{"items": [it], "actors": [adv] if adv != "" else [], "place": place, "importance": 3, "chronicle": true, "notable": true,
		"data": {"name": final_name, "kind": kind}})
	it["named"]["event"] = ev
	if Provenance.is_mine(it):
		mark_famous(it, "Named “%s” — %s." % [final_name, why])
		Recognition.record("named", final_name, "%s, from the Ironhand forge, was named “%s” — %s." % [base, final_name, why],
			{"uid": int(it.get("uid", -1)), "adv": adv, "def": str(it.get("def", ""))}, "named_%d" % int(it.get("uid", -1)))
		Shop.rep_change(2.0, "a piece from the Ironhand forge earned a name.")
		(st()["pending_fame"] as Array).append(int(it.get("uid", -1)))
		_village_reaction(it, adv)
	Events.inventory_changed.emit()
	return true


## The village takes notice: a toast and a raised cup at the Wyvern.
static func _village_reaction(it: Dictionary, adv: String) -> void:
	var who := Talk.npc_name(adv) if adv != "" else ""
	Events.toast.emit("Your work has a name now: %s%s." % [earned_name(it), (" (%s's %s)" % [who, _kind_word(it)]) if who != "" else ""], "legendary")
	Events.toast.emit("At the Wyvern tonight they raise a cup to %s — and to the smith who forged it." % earned_name(it), "good")
	for v in ["hilde", "martha", "tobin", "oswin"]:
		if not DB.character(v).is_empty():
			Social.change(v, 1.0, 0.5, "", "", false)


static func _kind_word(it: Dictionary) -> String:
	var s := Items.slot(it)
	if s == "weapon":
		return "blade" if Items.wtype(it) in ["sword", "dagger", "axe"] else "weapon"
	return Items.SLOT_LABEL.get(s, "piece").to_lower() if s not in ["armor"] else "armour"


## Expeditions._boss_down: the killing blow. Names the weapon after the real foe (smith's work or exceptional
## pieces). Returns the new name ("" when it already had one or cannot be named).
static func on_boss_kill(w: Dictionary, adv_id: String, boss: String, foe_kind: String, place_name_text: String, place_id := "") -> String:
	if not can_be_named(w) or is_named(w):
		return ""
	var a := Adv.get_a(adv_id)
	var who: String = str(a.get("name", Talk.npc_name(adv_id)))
	var nm := bane_name(w, boss, foe_kind)
	if name_item(w, nm, "boss", "it struck down %s in %s, wielded by %s" % [boss, place_name_text, who],
			{"adv": adv_id, "place": place_id, "enemy": boss}):
		return earned_name(w)
	return ""


## Optional: a 120%+ masterwork may be named by the smith at forging (Recognition.on_crafted).
static func on_crafted(it: Dictionary) -> void:
	if not Items.is_equipment(it) or float(it.get("quality", 0.0)) < 120.0 or is_named(it):
		return
	var n := 0
	for k in st()["famous"]:
		if str(st()["famous"][k].get("kind", "")) == "masterwork":
			n += 1
	var nm: String = MASTER_NAMES[n % MASTER_NAMES.size()] if n < MASTER_NAMES.size() else "the Masterwork of Day %d" % Game.day()
	if name_item(it, nm, "masterwork", "a %d%% masterwork, named by the smith at the anvil" % int(round(float(it["quality"])))):
		st()["famous"][str(it["uid"])]["kind"] = "masterwork"


## Daily: count campaigns and near-deaths per owner, name pieces that earned it, place fame commissions,
## remember the smith's pieces for the circulating pool.
static func on_day() -> void:
	if not Game.state.has("adventurers"):
		return
	for a in Adv.all().values():
		for slot in a.get("equipment", {}):
			var it: Dictionary = a["equipment"][slot]
			if it.is_empty() or not Provenance.applies(it):
				continue
			track(it, a)
	for uid in (st()["pending_fame"] as Array).duplicate():
		if not fame_commission(int(uid)).is_empty() or Game.day() % 5 == 0:
			(st()["pending_fame"] as Array).erase(uid)
	remember_pool()


## One worn piece: campaigns and near-deaths since we last looked, then the naming rules.
static func track(it: Dictionary, a: Dictionary) -> void:
	var p := Provenance.st(it)
	if not p.has("seen"):
		p["seen"] = {}
	var id := str(a.get("id", ""))
	var now_exp := int(a.get("expeditions", 0))
	var now_nd := int(a.get("deaths_cheated", 0))
	var seen: Dictionary = p["seen"]
	if not seen.has(id):
		seen[id] = {"exp": now_exp, "nd": now_nd}
	else:
		var s: Dictionary = seen[id]
		p["campaigns"] = int(p.get("campaigns", 0)) + maxi(0, now_exp - int(s.get("exp", 0)))
		var dnd := maxi(0, now_nd - int(s.get("nd", 0)))
		if dnd > 0:
			p["near_deaths"] = int(p.get("near_deaths", 0)) + dnd
			Lore.record("survived", "%s came through death's door again wearing %s." % [a.get("name", id), Items.display_name(it)],
				{"items": [it], "actors": [id], "importance": 1 if Provenance.is_notable(it) else 0})
		seen[id] = {"exp": now_exp, "nd": now_nd}
	check_names(it, a)


## The naming rules for a worn piece (survival, famous owner, many campaigns).
static func check_names(it: Dictionary, a: Dictionary) -> void:
	if is_named(it) or not can_be_named(it):
		return
	var p := Provenance.st(it)
	var who := str(a.get("name", ""))
	var id := str(a.get("id", ""))
	if int(p.get("near_deaths", 0)) >= SURVIVAL_N:
		name_item(it, _pick(it, ["Last Breath", "Death's Refusal"]), "survival",
			"%s came back from the edge of death %d times wearing it" % [who, int(p["near_deaths"])], {"adv": id})
	elif Expeditions.renown_title(a) == "Living Legend" and Provenance.is_mine(it) and Items.slot(it) in ["weapon", "shield", "armor"]:
		name_item(it, OWNER_FORMS.get(Items.slot(it), "%s's Oath") % who, "owner", "carried by %s, the Living Legend" % who, {"adv": id})
	elif int(p.get("campaigns", 0)) >= CAMPAIGN_N:
		name_item(it, "Old Faithful", "campaigns", "it went out on %d campaigns and always came home" % int(p["campaigns"]), {"adv": id})


# ======================================================================= famous creations
## Notes a deed of one of the smith's pieces in the famous-creations register (Hall of Fame).
static func mark_famous(it: Dictionary, deed: String) -> void:
	if it.is_empty() or not Provenance.is_mine(it):
		return
	var key := str(it.get("uid", -1))
	var f: Dictionary = st()["famous"].get(key, {})
	if f.is_empty():
		f = {"uid": int(it["uid"]), "first_day": Game.day(), "deeds": [], "kind": ""}
		st()["famous"][key] = f
	f["name"] = earned_name(it) if is_named(it) else str(it.get("name", ""))
	f["def"] = str(it.get("def", ""))
	f["rarity"] = str(it.get("rarity", "common"))
	f["epic"] = it.has("epic")
	f["named"] = is_named(it)
	for d in f["deeds"]:
		if str(d.get("text", "")) == deed:
			return
	(f["deeds"] as Array).append({"day": Game.day(), "text": deed})


## Recognition.grant_epic: an Epic deed joins the register (the item's history already holds the event).
static func on_epic(it: Dictionary, deed: String) -> void:
	mark_famous(it, "Epic — %s." % deed)


## The famous creations, most recently honoured first: [{uid, name, item, deeds, owner, owner_id, epic, rarity, named}].
static func famous_creations() -> Array:
	var out := []
	for k in st()["famous"]:
		var f: Dictionary = st()["famous"][k]
		var it := find(int(f.get("uid", -1)))
		var oid := Provenance.owner_id(it) if not it.is_empty() else ""
		var owner := "lost to the world" if it.is_empty() else (Provenance.SMITH_NAME if oid in ["", "smith"] else Provenance._who(oid))
		var last := 0
		for d in f.get("deeds", []):
			last = maxi(last, int(d.get("day", 0)))
		out.append({"uid": int(f["uid"]), "name": str(f.get("name", "")), "item": it, "deeds": f.get("deeds", []), "owner": owner, "owner_id": oid,
			"epic": bool(f.get("epic", false)) or it.has("epic"), "rarity": str(it.get("rarity", f.get("rarity", "common"))), "named": not it.is_empty() and is_named(it),
			"last": last})
	out.sort_custom(func(a, b): return int(a["last"]) > int(b["last"]) or (int(a["last"]) == int(b["last"]) and int(a["uid"]) > int(b["uid"])))
	return out


# ======================================================================= rumours & commissions
## Is there a named piece of the smith's for the village to talk about? (Cheap; no randomness.)
static func has_rumours() -> bool:
	if not Game.state.has("item_story"):
		return false
	for k in st()["famous"]:
		if bool(st()["famous"][k].get("named", false)):
			return true
	return false


## A line of village talk about a named piece of the smith's ("" when there is nothing to tell).
static func rumour_line(npc: String) -> String:
	var fs := famous_creations().filter(func(f): return bool(f["named"]))
	if fs.is_empty():
		return ""
	var f: Dictionary = fs[(Game.day() + npc.length()) % fs.size()]
	var it: Dictionary = f["item"]
	var nd: Dictionary = it.get("named", {})
	var owner := str(f["owner"])
	var why := str(nd.get("why", "it did great things"))
	var forms := [
		"\"Have you heard? %s — %s, folk say. That's your work, isn't it, smith?\"" % [f["name"], why],
		"\"They're toasting %s at the Wyvern again. %s carries it now. Your mark's on it, they say.\"" % [f["name"], owner],
		"\"My cousin swears %s %s. I'd give a month's wages just to hold it.\"" % [f["name"], why.trim_prefix("it ")],
	]
	st()["rumours_told"][npc] = Game.day()
	return str(forms[(Game.day() + int(f["uid"])) % forms.size()])


## After a piece becomes famous, another adventurer commissions "a blade like Wolfbane". Returns the order ({} = none).
static func fame_commission(uid: int) -> Dictionary:
	if st()["fame_orders"].has(str(uid)):
		return {}
	var it := find(uid)
	if it.is_empty() or not is_named(it):
		return {}
	var slot := Items.slot(it)
	if slot == "" or slot == "companion":
		return {}
	var owner := Provenance.owner_id(it)
	var pool := Adv.in_town().filter(func(a): return str(a["id"]) != owner and not Shop.refuses(str(a["id"])) \
		and Shop.open_orders().filter(func(o): return str(o["npc"]) == str(a["id"])).is_empty())
	if pool.is_empty():
		return {}
	pool.sort_custom(func(a, b): return int(a.get("renown", 0)) > int(b.get("renown", 0)) or (int(a.get("renown", 0)) == int(b.get("renown", 0)) and str(a["id"]) < str(b["id"])))
	var a: Dictionary = pool[0]
	var nm := earned_name(it)
	var note := "%s like %s — the one %s carries. Everyone at the Wyvern talks of it; make me its equal." % [Shop.slot_phrase(slot).capitalize(), nm,
		Provenance._who(owner) if owner not in ["", "smith"] else "you keep at the forge"]
	var o := Shop.create_order(str(a["id"]), slot, note)
	if o.is_empty():
		return {}
	o["inspired_by"] = uid
	o["reward"] = int(o["reward"]) + FAME_REWARD
	st()["fame_orders"][str(uid)] = str(o["id"])
	Lore.record("commission", "%s's fame brought a commission: %s wants %s just like it." % [nm, a["name"], Shop.slot_phrase(slot)],
		{"items": [it], "actors": [str(a["id"])], "importance": 2, "chronicle": true})
	mark_famous(it, "Inspired %s to commission its equal." % a["name"])
	return o


# ======================================================================= the item's story, summarised
## Lore events of a piece, in order (works for pieces no longer in the world too).
static func events_of(it: Dictionary) -> Array:
	if it.is_empty():
		return []
	return Provenance.story(it)


## The deeds worth telling: importance 2+ or the kinds that matter (not sales, repairs or notes).
static func deeds(it: Dictionary) -> Array:
	return events_of(it).filter(func(e): return int(e.get("importance", 0)) >= 2 or str(e.get("kind", "")) in ["named", "epic", "slew", "battle", "discovery", "survived", "inherited", "recovered", "cleared"])


## One line for the adventurer sheet: "your work, day 3 · 3 owners · slew the Barrow King · repaired twice".
static func summary(it: Dictionary) -> String:
	if it.is_empty() or not Provenance.applies(it):
		return ""
	var parts := []
	var m := Provenance.maker(it)
	if Provenance.is_mine(it):
		parts.append("your work, day %d" % int(m.get("day", 0)))
	else:
		parts.append("made by %s" % str(m.get("name", "an unknown smith")))
	var n := Provenance.owners(it).filter(func(o): return str(o.get("id", "")) != Provenance.SMITH_ID).size()
	if n > 0:
		parts.append("%d owner%s" % [n, "" if n == 1 else "s"])
	if is_named(it):
		parts.append("named “%s”" % earned_name(it))
	var ds := deeds(it).filter(func(e): return str(e.get("kind", "")) in ["slew", "battle", "discovery", "survived", "epic", "cleared"])
	if not ds.is_empty():
		var t := str(ds[-1].get("text", ""))
		parts.append(t.trim_suffix(".") if t.length() <= 70 else t.substr(0, 68) + "…")
	elif it.has("named"):
		parts.append(str(it["named"].get("why", "")))
	var rep := events_of(it).filter(func(e): return str(e.get("kind", "")) == "repaired").size()
	if rep > 0:
		parts.append("repaired %s" % (["once", "twice"][rep - 1] if rep <= 2 else "%d times" % rep))
	var rf := int(Provenance.st(it).get("reforged", 0))
	if rf > 0:
		parts.append("reforged" + ("" if rf == 1 else " ×%d" % rf))
	return " · ".join(PackedStringArray(parts))


## Rich record or a short one: exceptional pieces tell everything, routine ones a few lines.
static func is_rich(it: Dictionary) -> bool:
	return Provenance.is_notable(it) or is_named(it) or events_of(it).size() >= 6


# ======================================================================= "A Familiar Creation"
## Is this returning piece worth a moment? Named, Legendary or Epic pieces always; plain ones sometimes
## (when they have aged or changed hands).
static func worth_greeting(it: Dictionary) -> bool:
	if not Provenance.is_mine(it) or not Items.is_equipment(it):
		return false
	if Provenance.is_notable(it) or is_named(it) or it.has("epic") or str(it.get("rarity", "")) in ["legendary", "rare"]:
		return true
	var n := Provenance.owners(it).filter(func(o): return str(o.get("id", "")) != Provenance.SMITH_ID).size()
	return n >= 2 or Game.day() - int(Provenance.maker(it).get("day", Game.day())) >= PLAIN_REUNION_DAYS


static func reunion_key(occasion: String, who: String) -> String:
	return "%s|%s" % [occasion, who]


static func has_reunion(it: Dictionary, occasion: String, who: String) -> bool:
	var key := reunion_key(occasion, who)
	for r in Provenance.st(it).get("reunions", []):
		if str(r.get("key", "")) == key:
			return true
	return false


## Recognises a returning piece. Returns the card data the first time for this occasion and owner, {} otherwise.
## occasion: repair | offer | recovered | redeemed | bought | shown | returned | stranger.
static func recognise(it: Dictionary, occasion: String, who := "") -> Dictionary:
	if not worth_greeting(it) or has_reunion(it, occasion, who):
		return {}
	var p := Provenance.st(it)
	if not p.has("reunions"):
		p["reunions"] = []
	(p["reunions"] as Array).append({"key": reunion_key(occasion, who), "day": Game.day(), "occasion": occasion, "who": who})
	var data := card_data(it, occasion, who)
	Lore.record("reunion", "%s came back before its maker — %s." % [Items.display_name(it), str(data["occasion_text"]).trim_suffix(".")],
		{"items": [it], "actors": [who] if who != "" and not Adv.get_a(who).is_empty() else [], "place": "brindlewick", "importance": 2 if Provenance.is_notable(it) else 1})
	return data


## Recognise and, if it is a new reunion, show the parchment card. Returns true when the card was shown.
static func present(it: Dictionary, occasion: String, who := "") -> bool:
	var d := recognise(it, occasion, who)
	if d.is_empty():
		return false
	Events.open_panel.emit("familiar", {"uid": int(it.get("uid", -1)), "data": d})
	return true


const OCCASION := {
	"repair": "%s set it on the counter to be mended",
	"offer": "%s laid it out among the things brought home",
	"recovered": "it came home in a chest of a fallen adventurer's things",
	"redeemed": "it came back across the pawnbroker's counter",
	"bought": "it came back across your own counter",
	"returned": "it found its way back to the forge",
	"shown": "%s drew it to show you",
	"stranger": "%s brought it in, not knowing who made it",
}


## Everything the card shows: name, mark, day forged, achievements and the owners' journey.
static func card_data(it: Dictionary, occasion: String, who := "") -> Dictionary:
	var m := Provenance.maker(it)
	var occ := str(OCCASION.get(occasion, "it came back to the forge"))
	if occ.contains("%s"):
		occ = occ % (Talk.npc_name(who) if who != "" else "Someone")
	var ach := []
	if it.has("named"):
		ach.append("Named “%s” — %s." % [earned_name(it), str(it["named"].get("why", ""))])
	if it.has("epic"):
		ach.append("Epic — %s." % str(it["epic"].get("deed", "")))
	for e in deeds(it):
		if str(e.get("kind", "")) in ["named", "epic"]:
			continue
		var t := str(e.get("text", ""))
		if not ach.has(t):
			ach.append(t)
	var journey := []
	for o in Provenance.owners(it):
		journey.append({"id": str(o.get("id", "")), "name": str(o.get("name", "")), "how": str(o.get("how", "")), "from": int(o.get("from", 0)), "to": int(o.get("to", -1))})
	var day := int(m.get("day", 0))
	return {"uid": int(it.get("uid", -1)), "name": Items.display_name(it), "base": str(it.get("base_name", Items.def(it).get("name", ""))),
		"named": earned_name(it), "mark": str(m.get("mark", "unknown")), "mark_name": str(Provenance.mark(it).get("name", "")),
		"maker": str(m.get("name", "")), "day": day, "days_ago": maxi(0, Game.day() - day),
		"occasion": occasion, "occasion_text": occ.substr(0, 1).to_upper() + occ.substr(1) + ".", "who": who,
		"achievements": ach.slice(maxi(0, ach.size() - 4)), "journey": journey, "rich": is_rich(it)}


## The workshop counter: a waiting customer's piece (a repair) is recognised when the smith deals with them.
static func at_counter(npc: String) -> bool:
	var c := Shop.customer(npc)
	if c.is_empty() or not c.get("present", true):
		return false
	var it: Dictionary = c.get("item", {})
	if c.has("own_slot"):
		it = Adv.get_a(npc).get("equipment", {}).get(str(c["own_slot"]), it)
	if it.is_empty():
		return false
	return present(it, "stranger" if bool(c.get("old_blade", false)) else "repair", npc)


## Game.add_item: a piece comes into the smith's stores from elsewhere (chest, bag, buy-back, offer bought).
static func on_returned(it: Dictionary, how: String) -> void:
	if not Provenance.is_mine(it) or Provenance.owner_id(it) in ["", Provenance.SMITH_ID]:
		return
	var who := Provenance.owner_id(it)
	var occ := how if how in ["recovered", "redeemed", "bought"] else "returned"
	present(it, occ, who)


# ======================================================================= talking about a piece
## Dialogue options: ask an adventurer about a piece of yours that has a story.
static func talk_options(npc: String) -> Array:
	var a := Adv.get_a(npc)
	if a.is_empty() or str(a.get("status", "")) not in ["in_town", "injured"]:
		return []
	var out := []
	for slot in a.get("equipment", {}):
		var it: Dictionary = a["equipment"][slot]
		if it.is_empty() or not Provenance.is_mine(it):
			continue
		if is_named(it) or deeds(it).size() >= 1 or events_of(it).size() >= 3:
			out.append({"id": "itemstory_%d" % int(it["uid"]), "label": "Ask about %s — its travels" % Items.display_name(it)})
			if out.size() >= 2:
				break
	return out


static func talk_choose(npc: String, opt: String) -> Dictionary:
	if not opt.begins_with("itemstory_"):
		return {}
	var uid := int(opt.substr(10))
	var it := find(uid)
	if it.is_empty():
		return {"text": "\"Gone, that one. Long story.\""}
	present(it, "shown", npc)
	Social.change(npc, 1.0, 3.0, "", "", false)
	return {"text": travels_text(it, npc)}


## The owner tells the piece's story from its real events.
static func travels_text(it: Dictionary, npc: String) -> String:
	var lines := []
	var nm := Items.display_name(it)
	var day := int(Provenance.maker(it).get("day", 0))
	lines.append("\"This? %s — you made it, smith. Day %d, if the mark on the tang tells true.\"" % [nm, day] if day > 0 else "\"This? %s. Your mark's on it.\"" % nm)
	var ow := Provenance.owners(it).filter(func(o): return str(o.get("id", "")) not in [Provenance.SMITH_ID, npc])
	if not ow.is_empty():
		var names := []
		for o in ow:
			names.append(str(o.get("name", "")))
		lines.append("\"It passed through other hands before mine — %s.\"" % ", ".join(PackedStringArray(names)))
	var ds := deeds(it)
	for e in ds.slice(maxi(0, ds.size() - 4)):
		lines.append("[i]Day %d — %s[/i]" % [int(e.get("day", 0)), str(e.get("text", ""))])
	if ds.is_empty():
		var evs := events_of(it)
		for e2 in evs.slice(maxi(0, evs.size() - 3)):
			lines.append("[i]Day %d — %s[/i]" % [int(e2.get("day", 0)), str(e2.get("text", ""))])
	if is_named(it):
		lines.append("\"They call it %s now. I didn't name it — the road did.\"" % earned_name(it))
	else:
		lines.append("\"It's never let me down. That's all I ask of steel.\"")
	return "\n".join(PackedStringArray(lines))


# ======================================================================= workshop services
## Sharpening at the grinding wheel: a fresh edge (+attack for two expeditions), a little durability back.
## Returns {ok, text, before, after}. payer: the adventurer who brought it ("" = the smith's own stock).
static func sharpen(it: Dictionary, quality: float, payer := "") -> Dictionary:
	if it.is_empty() or Items.slot(it) != "weapon":
		return {"ok": false, "text": "Only a blade or weapon can be sharpened."}
	var before := _snapshot(it)
	var st2: Dictionary = it.get("stats", {})
	if st2.has("durability_max"):
		st2["durability"] = mini(int(st2["durability_max"]), int(st2.get("durability", 0)) + int(float(st2["durability_max"]) * clampf(quality / 400.0, 0.05, 0.3)))
	var val := 1 + int(quality / 40.0)
	var co: Dictionary = it.get("coating", {})
	if co.is_empty() or str(co.get("stat", "")) == "attack":
		it["coating"] = {"name": "Fresh Edge", "stat": "attack", "value": maxi(val, int(co.get("value", 0))), "uses": 2}
	var who := Talk.npc_name(payer) if payer != "" else ""
	var text := "Sharpened at the Ironhand grinding wheel%s (%d%%): a fresh edge, +%d attack for two expeditions." % [(" for " + who) if who != "" else "", int(quality), val]
	Provenance.workshop(it, "sharpened", text)
	if payer != "" and not Adv.get_a(payer).is_empty():
		var fee := 6 + int(Adv.get_a(payer).get("level", 1))
		var a := Adv.get_a(payer)
		a["gold"] = maxi(0, int(a.get("gold", 0)) - fee)
		Game.add_gold(fee, "repairs", "Sharpened %s's %s" % [who, it.get("name", "blade")])
		Social.change(payer, 2.0 if quality >= 70 else -1.0, 2.0, "", "", false)
	Game.grant_player_xp("smithing", 4)
	Events.inventory_changed.emit()
	return {"ok": true, "text": text, "before": before, "after": _snapshot(it), "kind": "sharpened"}


## Reforging at forge and anvil: the piece is reworked — made whole, and if the work is better than the
## original, its craftsmanship rises a little (at most +8 points). Maker, uid and name are kept.
## Costs one coal. Returns {ok, text, before, after}.
static func reforge(uid: int, quality: float) -> Dictionary:
	var it := Game.find_uid(uid)
	if it.is_empty() or not Items.is_equipment(it):
		return {"ok": false, "text": "Nothing to reforge."}
	if Game.count("coal") < 1:
		return {"ok": false, "text": "You need a sack of coal to heat the forge for reforging."}
	Game.remove_def("coal", 1)
	var before := _snapshot(it)
	var q0 := float(it.get("quality", 70.0))
	var gain := clampf((quality - q0) * 0.3, 0.0, 8.0) if quality > q0 else 0.0
	var q1 := minf(125.0, q0 + gain)
	var f := (0.7 + 0.3 * minf(q1 / 100.0, 1.3)) / (0.7 + 0.3 * minf(q0 / 100.0, 1.3))
	var st2: Dictionary = it.get("stats", {})
	for k in st2.keys():
		if k in ["durability", "durability_max"]:
			continue
		if st2[k] is float or st2[k] is int:
			var v := int(st2[k])
			st2[k] = maxi(v, int(round(float(v) * f))) if v > 0 else v
	if st2.has("durability_max"):
		st2["durability_max"] = maxi(int(st2["durability_max"]), int(round(float(st2["durability_max"]) * f)))
		st2["durability"] = int(st2["durability_max"])
	it.erase("broken")
	it["quality"] = q1
	var text := ("Reforged at the Ironhand forge (%d%%): craftsmanship %d%% → %d%%, made whole again." % [int(quality), int(round(q0)), int(round(q1))]) if gain >= 0.5 \
		else "Reforged at the Ironhand forge (%d%%): made whole again; the rework could not better the original %d%%." % [int(quality), int(round(q0))]
	Provenance.workshop(it, "reforged", text)
	Game.grant_player_xp("smithing", 12)
	Events.inventory_changed.emit()
	return {"ok": true, "text": text, "before": before, "after": _snapshot(it), "kind": "reforged"}


static func _snapshot(it: Dictionary) -> Dictionary:
	var st2: Dictionary = it.get("stats", {})
	return {"quality": float(it.get("quality", 0.0)), "attack": Items.stat(it, "attack"), "protection": Items.stat(it, "protection"),
		"durability": int(st2.get("durability", 0)), "durability_max": int(st2.get("durability_max", 0)), "broken": bool(it.get("broken", false))}


## Weapons adventurers in town would have sharpened: [[adv id, item]].
static func blades_in_town() -> Array:
	var out := []
	for a in Adv.in_town():
		var w: Dictionary = a.get("equipment", {}).get("weapon", {})
		if not w.is_empty():
			out.append([str(a["id"]), w])
	return out


# ======================================================================= the circulating pool & strangers
## Remembers the smith's pieces as light snapshots; pieces that have left the known world stay in the pool.
static func remember_pool() -> void:
	var pool: Dictionary = st()["pool"]
	var seen := {}
	for it in _known_items():
		if not Provenance.is_mine(it) or not Items.is_equipment(it):
			continue
		seen[str(it["uid"])] = true
		pool[str(it["uid"])] = it.duplicate(true)
	# keep the pool bounded: drop present pieces first (they are not circulating), then the oldest
	var keys := pool.keys()
	if keys.size() > POOL_CAP:
		keys.sort_custom(func(a, b): return int(a) < int(b))
		for k in keys:
			if pool.size() <= POOL_CAP:
				break
			if seen.has(k):
				pool.erase(k)
		keys = pool.keys()
		keys.sort_custom(func(a, b): return int(a) < int(b))
		while pool.size() > POOL_CAP:
			pool.erase(keys.pop_front())


static func _known_items() -> Array:
	var out := []
	for it in Game.inventory():
		out.append(it)
	for a in Adv.all().values():
		for s in a.get("equipment", {}):
			out.append(a["equipment"][s])
		for l in a.get("loot", []):
			out.append(l)
	for h in Game.state.get("hirelings", []):
		for s2 in h.get("equipment", {}):
			out.append(h["equipment"][s2])
	for o in Shop.offers():
		out.append(o.get("item", {}))
	return out.filter(func(x): return x is Dictionary and not (x as Dictionary).is_empty())


## Pieces of the smith's in the pool that are nowhere in the known world now (buried, lost, sold on).
static func circulating() -> Array:
	var present := {}
	for it in _known_items():
		present[str(it.get("uid", ""))] = true
	for c in Shop.customers():
		present[str(c.get("item", {}).get("uid", ""))] = true
	var out := []
	for k in st()["pool"]:
		if not present.has(k):
			out.append(st()["pool"][k])
	return out


## Shop.customer_hour: now and then a villager brings in an old blade bought from a pedlar — the smith's own work.
## Returns true when a stranger took the seat.
static func maybe_stranger() -> bool:
	if randf() > STRANGER_CHANCE or Game.day() - int(st().get("stranger_day", -99)) < STRANGER_GAP:
		return false
	return not stranger_visit().is_empty()


const STRANGERS := ["wenna", "oswin", "tobin", "eda", "jory", "martha"]
const PEDLARS := ["a pedlar on the coast road", "a tinker at the harvest fair", "a drover from the uplands", "a widow selling her late husband's things"]


## A villager arrives with a piece from the circulating pool. Returns the customer ({} = nobody/nothing).
static func stranger_visit(npc := "") -> Dictionary:
	var pool := circulating()
	if pool.is_empty() or Shop.free_seat() < 0:
		return {}
	pool.sort_custom(func(a, b): return int(a.get("uid", 0)) < int(b.get("uid", 0)))
	var src: Dictionary = pool[Game.day() % pool.size()]
	if npc == "":
		for v in STRANGERS:
			if not DB.character(v).is_empty() and not Shop.refuses(v) and not Shop.customers().any(func(c): return str(c["npc"]) == v):
				npc = v
				break
	if npc == "":
		return {}
	var it: Dictionary = src.duplicate(true)
	st()["pool"].erase(str(it["uid"]))
	var via: String = PEDLARS[int(it.get("uid", 0)) % PEDLARS.size()]
	Provenance.transfer(it, npc, "bought", "", "%s bought %s from %s." % [Talk.npc_name(npc), Items.display_name(it), via])
	var s2: Dictionary = it.get("stats", {})
	if s2.has("durability_max"):
		s2["durability"] = mini(int(s2.get("durability", 0)), int(int(s2["durability_max"]) * 0.35))
	var c := {"npc": npc, "want": "repair", "arrived": Game.day() * 24 + Game.hour(), "seat": Shop.free_seat(), "present": false,
		"item": it, "pay": 14, "old_blade": true, "via": via}
	Shop.customers().append(c)
	st()["stranger_day"] = Game.day()
	Events.customers_changed.emit()
	return c


## Shop.do_repair for a villager's piece: the mending is recorded; an old blade goes home with its new owner
## and back into the pool (it may turn up again, years on).
static func on_villager_repair(c: Dictionary, quality: float) -> void:
	var it: Dictionary = c.get("item", {})
	if it.is_empty() or not Provenance.applies(it):
		return
	var s2: Dictionary = it.get("stats", {})
	if s2.has("durability_max"):
		s2["durability"] = maxi(int(s2.get("durability", 0)), int(float(s2["durability_max"]) * clampf(0.55 + quality / 250.0, 0.5, 1.0)))
	it.erase("broken")
	Provenance.workshop(it, "repaired", "Repaired at the Ironhand forge for %s (%d%%)." % [Talk.npc_name(str(c["npc"])), int(quality)])
	if bool(c.get("old_blade", false)) and Provenance.is_mine(it):
		Social.change(str(c["npc"]), 3.0, 2.0, "old_blade_%d" % int(it["uid"]), "The smith knew my old blade at once — he made it, long ago.")
		st()["pool"][str(it["uid"])] = it.duplicate(true)
		st()["stranger_day"] = Game.day() + 14
