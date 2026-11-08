## Item personalities (ItemSpirit, iteration 011): rare awakening, type from real history, authored lines filled
## from that history, cooldowns, the mute setting and determinism.
extends SuiteCase

const SMOKE := ["test_minority_of_candidates", "test_cooldowns_prevent_spam", "test_mute_silences_it"]


## A piece whose fixed uid roll gives it a spirit (or not, with want = false).
func _piece(def: String, opts := {}, want := true) -> Dictionary:
	for i in 400:
		var it := Items.make(def, opts)
		var lucky := ItemSpirit._roll("spirit:%d" % int(it["uid"])) < ItemSpirit.CHANCE
		if lucky == want:
			return it
	return {}


func _legend(want := true) -> Dictionary:
	return _piece("sword_iron", {"rarity": "legendary", "crafted_by": "Brannoc Ironhand", "quality": 104.0}, want)


func _slay(it: Dictionary, enemy: String, place: String, place_id: String) -> void:
	Lore.record("slew", "%s felled %s in %s." % [it["name"], enemy, place], {"items": [it], "place": place_id, "importance": 2,
		"data": {"enemy": enemy, "place_name": place}})


func _voices(on: bool, freq := "normal") -> void:
	Settings.values[ItemSpirit.VOICE_KEY] = on
	Settings.values[ItemSpirit.FREQ_KEY] = freq


# ------------------------------------------------------------------ rarity
func test_minority_of_candidates() -> void:
	ItemSpirit.wire()
	var n := 300
	var spirits := 0
	for i in n:
		var it := Items.make("sword_iron", {"rarity": "legendary"})
		check(ItemSpirit.is_candidate(it), "a legendary is a candidate")
		if not ItemSpirit.ensure(it).is_empty():
			spirits += 1
	note("%d of %d legendaries carry a spirit" % [spirits, n])
	check(spirits > n * 0.15 and spirits < n * 0.45, "only a minority of candidates wake (%d/%d)" % [spirits, n])
	check(spirits > 0, "but some do")


func test_ordinary_items_never_speak() -> void:
	ItemSpirit.wire()
	_voices(true)
	var woke := 0
	for def: String in ["sword_iron", "dagger", "helm_iron", "shield_round", "axe_hand"]:
		for i in 60:
			var it := Items.make(def, {"quality": 90.0, "crafted_by": "Brannoc Ironhand"})
			Game.add_item(it, false)
			Provenance.forged(it)
			Provenance.transfer(it, "sigrun", "sold")
			if ItemSpirit.is_candidate(it) or not ItemSpirit.ensure(it).is_empty() or ItemSpirit.speak(it, "repair", true) != "":
				woke += 1
	eq(woke, 0, "no ordinary piece ever wakes or speaks")
	var ore := Items.make("ore_iron", {"qty": 3})
	eq(ItemSpirit.speak(ore, "inspect", true), "", "materials never speak")


# ------------------------------------------------------------------ awakening
func test_awakens_after_deed_and_persists() -> void:
	ItemSpirit.wire()
	_voices(true)
	var it := _piece("sword_iron", {"crafted_by": "Brannoc Ironhand", "quality": 96.0})
	Game.add_item(it, false)
	Provenance.forged(it)
	check(not ItemSpirit.is_candidate(it), "a plain sword is no candidate before its deed")
	check(ItemSpirit.ensure(it).is_empty() and ItemSpirit.speak(it, "repair", true) == "", "it sleeps")
	# the deed: Epic distinction (the boss kill in the Barrow Fields)
	Recognition.grant_epic(it, "struck the killing blow on the Barrow King in the Barrow Fields", "sigrun", "boss")
	var sp := ItemSpirit.spirit(it)
	check(not sp.is_empty(), "the Epic deed woke it (through the Chronicle hook)")
	eq(str(sp.get("cause", "")), "epic", "its cause is the deed")
	eq(int(sp.get("awakened_day", -1)), Game.day(), "awakened today")
	var woke_ev := Lore.of_item(int(it["uid"])).filter(func(e): return str(e["kind"]) == "awakened")
	eq(woke_ev.size(), 1, "the awakening is one Lore event in the piece's story")
	# an arcane piece wakes on a significant Lore event (its bearer's death)
	var staff := _piece("sword_iron", {"crafted_by": "Brannoc Ironhand"})
	staff["arcane_glow"] = true
	Game.add_item(staff, false)
	check(ItemSpirit.is_candidate(staff) and not ItemSpirit.awake(staff), "an arcane piece waits for its deed")
	Lore.record("death", "Elowen fell in the Mirewood with %s in hand." % staff["name"], {"items": [staff], "place": "mirewood", "importance": 2})
	check(ItemSpirit.awake(staff), "its bearer's death woke the arcane piece")
	# persisted
	var t := str(sp["type"])
	ItemSpirit.speak(it, "inspect", true)
	var said := int(ItemSpirit.spirit(it).get("lines_said", 0))
	check(save_load("t_pers_roundtrip"), "save and load")
	var back := Game.find_uid(int(it["uid"]))
	var sp2 := ItemSpirit.spirit(back)
	check(not sp2.is_empty(), "the spirit survives save/load")
	eq(str(sp2.get("type", "")), t, "with the same type")
	eq(int(sp2.get("lines_said", 0)), said, "and the same line count")
	check(ItemSpirit.awake(Game.find_uid(int(staff["uid"]))), "the arcane piece is still awake after loading")


func test_innate_legendary_wakes_at_the_forge() -> void:
	ItemSpirit.wire()
	var it := _legend(true)
	Game.add_item(it, false)
	Provenance.forged(it)
	check(ItemSpirit.awake(it), "a destined legendary wakes when it is forged")
	eq(str(ItemSpirit.spirit(it).get("cause", "")), "forged", "it woke at the forge")
	# it grows into its character: the type settles with its first words, from the history until then
	_voices(true)
	Provenance.transfer(it, "aldric", "sold")
	Lore.record("death", "Aldric fell with %s in hand." % it["name"], {"items": [it], "place": "kings_road", "importance": 2})
	Provenance.transfer(it, "hilde", "inherited")
	Lore.record("death", "Hilde fell too.", {"items": [it], "place": "mirewood", "importance": 2})
	check(ItemSpirit.speak(it, "inspect", true) != "", "its first words")
	eq(str(ItemSpirit.spirit(it)["type"]), "melancholy", "its character settled from what happened to it")
	for i in 5:
		_slay(it, "a troll", "Ironroot", "ironroot_mine")
	ItemSpirit.settle(it)
	eq(str(ItemSpirit.spirit(it)["type"]), "melancholy", "once it has spoken, its character never changes")
	var dud := _legend(false)
	Game.add_item(dud, false)
	Provenance.forged(dud)
	check(not ItemSpirit.awake(dud) and ItemSpirit.ensure(dud).is_empty(), "a legendary without the roll stays silent")


# ------------------------------------------------------------------ type from history
func test_type_from_history_is_deterministic() -> void:
	ItemSpirit.wire()
	# a blade with many kills, carried by a barbarian
	var a := _legend(true)
	Game.add_item(a, false)
	Provenance.transfer(a, "varn", "sold")
	for i in 4:
		_slay(a, "a barrow-wight", "the Barrow Fields", "barrow_fields")
	a["kills"] = 14
	var ta := ItemSpirit.derive_type(a)
	eq(ItemSpirit.derive_type(a), ta, "the same history gives the same type")
	check(ta in ["bloodthirsty", "proud"], "kills make it bloodthirsty or proud (%s)" % ta)
	# a blade whose bearers died
	var b := _legend(true)
	Game.add_item(b, false)
	Provenance.transfer(b, "aldric", "sold")
	Lore.record("death", "Aldric died on the road with %s at his side." % b["name"], {"items": [b], "place": "kings_road", "importance": 2})
	Provenance.transfer(b, "hilde", "inherited")
	Lore.record("death", "Hilde was lost in the marsh.", {"items": [b], "place": "mirewood", "importance": 2})
	eq(ItemSpirit.derive_type(b), "melancholy", "dead bearers make it melancholy")
	# a blade that passed through many hands
	var c := _legend(true)
	c["def"] = "dagger"
	Game.add_item(c, false)
	for who: String in ["martha", "tobin", "wenna", "oswin", "jory", "eda"]:
		Provenance.transfer(c, who, "sold")
	eq(ItemSpirit.derive_type(c), "sarcastic", "many hands make it sarcastic")
	# a wizard's piece
	var d := _legend(true)
	Game.add_item(d, false)
	Provenance.transfer(d, "elowen", "sold")
	eq(ItemSpirit.derive_type(d), "wise", "a wizard's piece is wise")
	# a shield that took the blows
	var s := _piece("shield_round", {"rarity": "legendary"})
	Game.add_item(s, false)
	Lore.record("survived", "%s turned a troll's club." % s["name"], {"items": [s], "place": "ironroot_mine", "importance": 1})
	eq(ItemSpirit.derive_type(s), "dutiful", "a shield that saved its bearer is dutiful")
	# awakening stores the type once; it does not drift
	var sp := ItemSpirit.ensure(a)
	eq(str(sp.get("type", "")), ta, "the awakened type is the derived one")


# ------------------------------------------------------------------ lines
func test_lines_fill_from_real_history() -> void:
	ItemSpirit.wire()
	_voices(true)
	var it := _legend(true)
	Game.add_item(it, false)
	Provenance.forged(it)
	Provenance.transfer(it, "sigrun", "sold")
	_slay(it, "the Bone Wyrm", "the Barrow Fields", "barrow_fields")
	var f := ItemSpirit.facts(it)
	eq(str(f.get("maker", "")), Provenance.SMITH_NAME, "maker from provenance")
	eq(str(f.get("first_owner", "")), str(Adv.get_a("sigrun").get("name", "?")), "first owner from the owners chain")
	eq(str(f.get("enemy", "")), "the Bone Wyrm", "enemy from the kill event")
	eq(str(f.get("place", "")), "the Barrow Fields", "place from the kill event")
	check(not f.has("deed"), "no deed placeholder without a deed")
	var sp: Dictionary = ItemSpirit.ensure(it)
	var all_lines := []
	var history_lines := 0
	for t: String in ItemSpirit.TYPES:
		sp["type"] = t
		for ctx: String in ["repair", "sharpen", "reforge", "enchant", "treat", "inspect", "idle", "maker", "quench"]:
			for n in 6:
				sp["lines_said"] = n
				sp["recent"] = []
				var l := ItemSpirit.pick_line(it, ctx)
				check(not l.is_empty(), "%s has a line for %s" % [t, ctx])
				var txt := str(l.get("text", ""))
				check(not txt.contains("{") and not txt.contains("}"), "every placeholder is filled: %s" % txt)
				check(not str(l.get("raw", "")).contains("{deed}"), "no line needs a deed the piece never did")
				all_lines.append(txt)
				if txt.contains("Bone Wyrm") or txt.contains("Barrow Fields") or txt.contains(str(f.get("first_owner", "~"))) or txt.contains(Provenance.SMITH_NAME):
					history_lines += 1
	note("%d lines picked, %d speak of the piece's own history" % [all_lines.size(), history_lines])
	check(history_lines > all_lines.size() / 5, "lines prefer the piece's own history when they can")
	# a deed makes the deed lines possible
	it["epic"] = {"day": Game.day(), "deed": "struck the killing blow on the Bone Wyrm"}
	sp["type"] = "proud"
	var deed_seen := false
	for n in 40:
		sp["lines_said"] = n
		sp["recent"] = []
		if str(ItemSpirit.pick_line(it, "inspect").get("text", "")).begins_with("Struck the killing blow"):
			deed_seen = true
	check(deed_seen, "with a deed, the deed line can be said (capitalised)")


func test_same_input_same_line() -> void:
	ItemSpirit.wire()
	_voices(true)
	var it := _legend(true)
	Game.add_item(it, false)
	Provenance.transfer(it, "pip", "sold")
	ItemSpirit.ensure(it)
	var l1 := ItemSpirit.pick_line(it, "repair")
	var l2 := ItemSpirit.pick_line(it, "repair")
	eq(l1, l2, "the same state picks the same line")
	var snap: Dictionary = ItemSpirit.spirit(it).duplicate(true)
	var g: Dictionary = ItemSpirit.gst().duplicate(true)
	var s1 := ItemSpirit.speak(it, "repair", true)
	Provenance.st(it)["spirit"] = snap.duplicate(true)
	Game.state["spirits"] = g.duplicate(true)
	var s2 := ItemSpirit.speak(it, "repair", true)
	check(s1 != "", "it spoke")
	eq(s2, s1, "replaying the same moment says the same line")
	# no immediate repeats across a run of lines
	var seen := []
	var repeats := 0
	for i in 8:
		Game.advance_minutes(ItemSpirit.ITEM_COOLDOWN + 1)
		var s := ItemSpirit.speak(it, "repair", true)
		if not seen.is_empty() and s == seen[seen.size() - 1]:
			repeats += 1
		seen.append(s)
	eq(repeats, 0, "never the same line twice in a row")


# ------------------------------------------------------------------ cooldowns & settings
func test_cooldowns_prevent_spam() -> void:
	ItemSpirit.wire()
	_voices(true)
	var a := _legend(true)
	var b := _legend(true)
	Game.add_item(a, false)
	Game.add_item(b, false)
	var said := 0
	for i in 12:
		if ItemSpirit.speak(a, "repair", true) != "":
			said += 1
	eq(said, 1, "twelve calls in a row: one line")
	eq(ItemSpirit.speak(b, "repair", true), "", "another piece waits for the global cooldown")
	Game.advance_minutes(ItemSpirit.GLOBAL_COOLDOWN + 1)
	check(ItemSpirit.speak(b, "repair", true) != "", "after the global cooldown another piece may speak")
	Game.advance_minutes(ItemSpirit.GLOBAL_COOLDOWN + 1)
	eq(ItemSpirit.speak(a, "repair", true), "", "the first piece is still on its own cooldown")
	Game.advance_minutes(ItemSpirit.ITEM_COOLDOWN)
	check(ItemSpirit.speak(a, "repair", true) != "", "and speaks again once it has passed")
	# without force, over a long working day the chance keeps it occasional
	var c := _legend(true)
	Game.add_item(c, false)
	var lines := 0
	for i in 200:
		Game.advance_minutes(5)
		if ItemSpirit.speak(c, "repair") != "":
			lines += 1
	note("%d lines in 1000 game minutes of continual work" % lines)
	check(lines >= 1 and lines <= 1000 / ItemSpirit.ITEM_COOLDOWN + 1, "occasional, not constant (%d)" % lines)
	# rare frequency stretches the cooldowns
	_voices(true, "rare")
	check(ItemSpirit.item_cooldown() > ItemSpirit.ITEM_COOLDOWN and ItemSpirit.global_cooldown() > ItemSpirit.GLOBAL_COOLDOWN, "'rarely' waits longer")
	_voices(true)


func test_mute_silences_it() -> void:
	ItemSpirit.wire()
	var before: Variant = Settings.get_value(ItemSpirit.VOICE_KEY, true)
	_voices(false)
	var it := _legend(true)
	Game.add_item(it, false)
	var said := 0
	for i in 10:
		Game.advance_minutes(ItemSpirit.ITEM_COOLDOWN + 1)
		if ItemSpirit.speak(it, "repair", true) != "":
			said += 1
	eq(said, 0, "with item voices off nothing speaks")
	check(ItemSpirit.awake(it), "but the awakening is still tracked")
	eq(ItemSpirit.quiet_reason(it), "muted", "the reason is the setting")
	_voices(true)
	check(ItemSpirit.speak(it, "repair", true) != "", "turned back on, it speaks")
	Settings.values[ItemSpirit.VOICE_KEY] = before


# ------------------------------------------------------------------ hooks
func test_workshop_hooks_speak() -> void:
	ItemSpirit.wire()
	_voices(true)
	var it := _legend(true)
	Game.add_item(it, false)
	give("oil_whetstone")
	var s0 := ItemSpirit.serial
	Crafting.treat(int(it["uid"]), "oil_whetstone")
	check(ItemSpirit.serial == s0 + 1 and int(ItemSpirit.last.get("uid", -1)) == int(it["uid"]), "treating it: its first words come at once")
	eq(str(ItemSpirit.last.get("context", "")), "treat", "in the treatment context")
	# repair of an adventurer's own worn piece
	var adv := ""
	for a in Adv.all().values():
		if a["status"] == "in_town":
			adv = str(a["id"])
			break
	if adv == "":
		skip("no adventurer in town")
		return
	var gear := _legend(true)
	Adv.get_a(adv)["equipment"]["weapon"] = gear
	Game.advance_minutes(ItemSpirit.GLOBAL_COOLDOWN + 1)
	Shop.customers().append({"npc": adv, "want": "repair", "own_slot": "weapon", "item": gear, "pay": 12, "seat": 0, "present": true,
		"arrived": Game.day() * 24 + Game.hour()})
	eq(int(ItemSpirit.repair_item(adv).get("uid", -1)), int(gear["uid"]), "the repair piece is found")
	var s1 := ItemSpirit.serial
	Shop.do_repair(adv, 90.0)
	check(ItemSpirit.serial == s1 + 1 and int(ItemSpirit.last.get("uid", -1)) == int(gear["uid"]), "the piece on the grinding wheel speaks")
