## Adventurer biographies (Pilot 003, canonical v1.5 §8.1): every adventurer's pre-game history is about 100–150 words,
## agrees with their established facts, is written once and never rewritten, survives save/load, reaches older saves
## without touching anything else, leaves adventurer generation alone, and is shown in the character sheet's overview.
extends SuiteCase

const SMOKE := ["test_every_adventurer_has_a_consistent_biography", "test_written_once_and_kept_through_save_load"]
const FIXTURES := "res://tests/fixtures/saves/"
const RE_HE := "\\b(he|him|his|himself)\\b"
const RE_SHE := "\\b(she|herself)\\b"


func _adventurer_ids() -> Array:
	return DB.characters.keys().filter(func(id): return str(DB.character(str(id)).get("kind", "")) == "adventurer")


func _has_word(t: String, pattern: String) -> bool:
	var re := RegEx.new()
	re.compile(pattern)
	return re.search(t.to_lower()) != null


func test_every_adventurer_has_a_consistent_biography() -> void:
	var ids := _adventurer_ids()
	eq(ids.size(), 24, "the cast: 24 adventurers in characters.json")
	var seen := {}
	var lo := 999
	var hi := 0
	for id in ids:
		# exactly as the game makes them (story characters and reserves alike)
		var a := Living.make_adventurer(str(id), Living.rng_for("t_bio_" + str(id)), Living.is_story(str(id)))
		var t := str(a.get(Biography.KEY, ""))
		var w := Biography.word_count(t)
		lo = mini(lo, w)
		hi = maxi(hi, w)
		check(w >= 100 and w <= 150, "%s: %d words (100–150)" % [id, w])
		check(t.begins_with(str(a["name"])), "%s: it opens with their name" % id)
		check(not t.contains("{") and not t.contains("}"), "%s: no placeholder left" % id)
		check(not seen.has(t), "%s: a biography of their own" % id)
		seen[t] = true
		eq(Biography.compose(a), t, "%s: the same world seed writes the same biography" % id)
		var look: Dictionary = DB.character(str(id)).get("look", {})
		if bool(look.get("female", false)):
			check(not _has_word(t, RE_HE), "%s: her pronouns follow her established look" % id)
		else:
			check(not _has_word(t, RE_SHE), "%s: his pronouns follow his established look" % id)
	note("biography lengths %d–%d words over %d adventurers" % [lo, hi, ids.size()])
	# the established facts it must agree with (family links, personality lines)
	var facts := {"mira": ["Aldric", "grocer's girl"], "kestra": ["Tobin", "owes"], "garrick": ["Martha", "father died"],
		"rv_liesl": ["husband"], "rv_brenna": ["brothers"], "rv_fen": ["poacher's daughter"], "rv_mattias": ["southern abbey"],
		"rv_dagny": ["dwarven"], "rv_ewan": ["elves"], "rv_ivo": ["halfling"], "rv_korvak": ["half-orc"], "rv_perrin": ["halfling"]}
	for id in facts:
		var t := Biography.compose(Living.make_adventurer(str(id), Living.rng_for("t_bio_" + str(id)), Living.is_story(str(id))))
		for f in facts[id]:
			check(t.contains(str(f)), "%s: agrees with the established fact \"%s\"" % [id, f])
	# Mira grew up here: no arrival line for her
	var mira := Biography.compose(Living.make_adventurer("mira", Living.rng_for("t_bio_mira"), true))
	check(not mira.contains("arriving") and not mira.contains("reached the village"), "Mira grew up in the village: no arrival")


func test_written_once_and_kept_through_save_load() -> void:
	fresh_game()
	var before := {}
	for id in Adv.all():
		var a: Dictionary = Adv.all()[id]
		check(str(a.get(Biography.KEY, "")) != "", "%s: written when the roster was made" % id)
		before[id] = str(a.get(Biography.KEY, ""))
	# never rewritten: later changes to the adventurer do not touch it
	var m := Adv.get_a("mira")
	m["trait"] = "reckless"
	m["level"] = 9
	(m["goals"] as Array).clear()
	Biography.ensure(m)
	eq(Biography.text(m), str(before["mira"]), "Mira's biography is not rewritten when she changes")
	eq(int(m.get("bio_v", 0)), Biography.VERSION, "the template version it was written with is kept")
	check(save_load("t_bio_roundtrip"), "save and load")
	for id in before:
		eq(str(Adv.get_a(str(id)).get(Biography.KEY, "")), str(before[id]), "%s: the biography survives save/load" % id)


func test_older_save_gains_one_without_other_changes() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURES + "build-0.14.6.json"))
	if not check(raw is Dictionary, "the 0.14.6 golden save is present"):
		return
	var old_adv: Dictionary = (raw as Dictionary)["data"].get("adventurers", {})
	check(not old_adv.is_empty() and old_adv.values().all(func(a): return not (a as Dictionary).has(Biography.KEY)),
		"the old save has adventurers and no biographies")
	var f := FileAccess.open(Saves.path("t_bio_old"), FileAccess.WRITE)
	f.store_string(FileAccess.get_file_as_string(FIXTURES + "build-0.14.6.json"))
	f.close()
	if not check(Saves.load_slot("t_bio_old"), "the 0.14.6 save loads"):
		return
	for id in Adv.all():
		var a: Dictionary = Adv.all()[id]
		var without: Dictionary = a.duplicate(true)
		without.erase(Biography.KEY)
		without.erase("bio_v")
		var hist := (a.get("history", []) as Array).size()
		var t := Biography.text(a)
		check(Biography.word_count(t) >= 100, "%s: gains a biography" % id)
		var after: Dictionary = a.duplicate(true)
		after.erase(Biography.KEY)
		after.erase("bio_v")
		eq(JSON.stringify(after, "", true), JSON.stringify(without, "", true), "%s: nothing else about them changes" % id)
		eq((a.get("history", []) as Array).size(), hist, "%s: their recorded history is untouched" % id)
	var keep := Biography.text(Adv.get_a("garrick"))
	check(save_load("t_bio_old_roundtrip"), "saved again and reloaded")
	eq(Biography.text(Adv.get_a("garrick")), keep, "the biography written for the old save is kept from then on")
	Saves.delete("t_bio_old")


func test_generation_untouched() -> void:
	# the biography has its own random generator: the game's random sequence is the same with or without it
	var a := Living.make_adventurer("rv_fen", Living.rng_for("t_bio_gen"), false)
	var b := Living.make_adventurer("rv_fen", Living.rng_for("t_bio_gen"), false)
	seed(424242)
	var x := [randi(), randi()]
	seed(424242)
	Biography.compose(a)
	eq([randi(), randi()], x, "composing a biography consumes nothing from the global random sequence")
	# an old-format adventurer gains exactly the biography and nothing else
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURES + "build-0.14.6.json"))
	if raw is Dictionary:
		for id in (raw as Dictionary)["data"].get("adventurers", {}):
			var old: Dictionary = (raw as Dictionary)["data"]["adventurers"][id]
			var copy: Dictionary = old.duplicate(true)
			Biography.ensure(copy)
			check(copy.has(Biography.KEY) and copy.has("bio_v"), "%s (old save): gains a biography" % id)
			copy.erase(Biography.KEY)
			copy.erase("bio_v")
			eq(JSON.stringify(copy, "", true), JSON.stringify(old, "", true), "%s (old save): nothing else is added or changed" % id)
	for k in a:
		if k != Biography.KEY and k != "bio_v" and k != "equipment" and k != "depart_day" and k != "joined_day":
			eq(JSON.stringify(a[k]), JSON.stringify(b[k]), "rv_fen: '%s' is generated the same way each time" % k)
	# composing again draws nothing from the roster's generator
	var r2 := Living.rng_for("t_bio_gen2")
	var r3 := Living.rng_for("t_bio_gen2")
	Biography.compose(a)
	eq(r2.randi(), r3.randi(), "composing a biography leaves other generators untouched")


func test_overview_shows_it() -> void:
	fresh_game()
	var root := (Engine.get_main_loop() as SceneTree).root
	var host := root.get_child(root.get_child_count() - 1)
	var dp := DossierPanel.new("sigrun")
	host.add_child(dp)
	var box := dp.find_child("Biography", true, false)
	check(box is ScrollContainer, "the overview has a scrollable Biography section")
	var lbl := dp.find_child("BiographyText", true, false) as Label
	check(lbl != null and lbl.text == Biography.text(Adv.get_a("sigrun")), "…showing her biography, word-wrapped")
	check(lbl != null and lbl.autowrap_mode != TextServer.AUTOWRAP_OFF, "…which wraps to the page")
	host.remove_child(dp)
	dp.queue_free()
