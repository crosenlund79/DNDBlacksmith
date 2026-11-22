## R3 "One History": the Chronicle is a view of Lore, old feeds migrate without loss, routine work folds into digests
## without breaking any link, causes are recorded, and seeded streams replay a campaign bit for bit
## (docs/final_completion/FINAL_DEVELOPMENT_ROADMAP.md R3 acceptance).
extends SuiteCase

const SMOKE := ["test_every_chronicle_line_is_a_lore_event", "test_streams_are_independent"]


func _days(n: int) -> void:
	for i in n:
		Game.advance_minutes(1440)


# ------------------------------------------------------------------ 1. one store
func test_every_chronicle_line_is_a_lore_event() -> void:
	fresh_game()
	_days(30)
	var feed := Chronicle.entries()
	check(feed.size() >= 10, "a month of play writes a news feed (%d entries)" % feed.size())
	var bad := 0
	for c in feed:
		var e := Lore.event(str(c.get("event", "")))
		if e.is_empty() or str(e.get("text", "")) != str(c["text"]) or str(e.get("chron", "")) != str(c["kind"]):
			bad += 1
	eq(bad, 0, "every feed line is a Lore event with the same text and kind")
	check(not Game.state.has("chronicle"), "no separate feed store exists")
	eq((Lore.st()["chron_ids"] as Array).size(), feed.size(), "the feed is exactly the Lore events marked for it")
	# a direct feed writer reaches the people it names (a hireling's death used to vanish from histories)
	var aid := str(Adv.all().keys()[0])
	var c2 := Chronicle.add("death", "Test: a death written straight to the feed.", {"adv": aid})
	check((Adv.get_a(aid).get("lore", []) as Array).has(str(c2["event"])), "the person's history holds it")
	check(Lore.of_actor(aid).any(func(x): return str(x["id"]) == str(c2["event"])), "and Lore finds it by actor")


func test_feed_is_not_capped() -> void:
	fresh_game()
	var n0 := Chronicle.entries().size()
	for i in 450:
		Chronicle.add("social", "Feed line %d." % i, {})
	eq(Chronicle.entries().size(), n0 + 450, "450 more lines are all kept (the old feed kept 400)")
	eq(str(Chronicle.entries()[n0]["text"]), "Feed line 0.", "the oldest is still there")


# ------------------------------------------------------------------ 2. migration of old feeds
func _golden_raw(name: String) -> Dictionary:
	var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/saves/%s.json" % name))
	return Saves._restore_ints(doc["data"]) if doc is Dictionary else {}


func test_golden_feeds_become_lore_with_the_same_fame() -> void:
	for name in ["build-0.11.2", "build-0.14.6", "artifact-0.16.21", "artifact-0.17"]:
		var raw := _golden_raw(name)
		var old: Array = raw.get("chronicle", [])
		var hof := JSON.stringify(raw.get("hall_of_fame", []))
		var epic := {}
		for x in ItemRegistry.locations(ItemRegistry.ALL, raw, true):
			var it: Dictionary = x["item"]
			if it.has("epic"):
				epic[int(it["uid"])] = JSON.stringify(it["epic"])
		var data := raw.duplicate(true)
		SaveMigrations.run(data)
		var s: Dictionary = data["lore"]
		eq((s["chron_ids"] as Array).size(), old.size(), "%s: all %d feed entries are Lore events" % [name, old.size()])
		var texts_old := old.map(func(c): return str(c["text"]))
		var texts_new := (s["chron_ids"] as Array).map(func(id): return str(s["events"][id]["text"]))
		eq(texts_new, texts_old, "%s: same texts, same order" % name)
		var linked := 0
		for c in old:
			var who: Array = (c.get("refs", {}).get("party", []) as Array).duplicate()
			who.append(str(c.get("refs", {}).get("adv", "")))
			if who.any(func(w): return str(w) != "" and data["adventurers"].has(str(w))):
				linked += 1
		var held := 0
		for id in s["chron_ids"]:
			var e: Dictionary = s["events"][id]
			for a in e.get("actors", []):
				if data["adventurers"].has(a) and (data["adventurers"][a].get("lore", []) as Array).has(id):
					held += 1
					break
		eq(held, linked, "%s: every entry naming an adventurer is in their history (%d)" % [name, linked])
		eq(JSON.stringify(data.get("hall_of_fame", [])), hof, "%s: the Hall of Fame is unchanged" % name)
		var epic2 := {}
		for x in ItemRegistry.locations(ItemRegistry.ALL, data, true):
			var it: Dictionary = x["item"]
			if it.has("epic"):
				epic2[int(it["uid"])] = JSON.stringify(it["epic"])
		eq(epic2, epic, "%s: every Epic distinction is unchanged (%d)" % [name, epic.size()])
		check(not data.has("chronicle"), "%s: the separate feed is gone" % name)
		var again := data.duplicate(true)
		eq(Lore.migrate_chronicle(again), 0, "%s: step 11 again changes nothing" % name)


# ------------------------------------------------------------------ 3. retention keeps every link
func test_routine_work_folds_without_breaking_links() -> void:
	fresh_game()
	var blade := Items.make("sword_iron", {"quality": 60.0})
	Provenance.forged(blade)
	Game.add_item(blade, false)
	var sold := Lore.record("sold", "Test sale of the blade.", {"items": [blade], "importance": 0})
	var routine := []
	for i in 6:
		routine.append(Provenance.workshop(blade, "repaired", "Routine repair %d." % i))
	var gone := Items.make("dagger", {"quality": 55.0})
	Provenance.forged(gone)
	Game.add_item(gone, false)
	var gone_rep := [Provenance.workshop(gone, "repaired", "A repair of the dagger."), Provenance.workshop(gone, "repaired", "Another repair.")]
	Game.inventory().erase(gone)
	Provenance.lose(gone, "the millpond", "dropped in the millpond")
	var tb := ItemRegistry.tombstone_of(int(gone["uid"]))
	var cause := Lore.record("battle", "Test: a fight the repair answered.", {"importance": 1})
	var answered := Lore.record("repaired", "A repair after the fight (linked).", {"items": [blade], "importance": 0, "because": [cause]})
	var linked := Lore.record("note", "A note something points at.", {"items": [blade], "importance": 0})
	Lore.record("deed", "Test: a deed caused by the note.", {"importance": 2, "because": [linked]})
	var before_hist := (Provenance.st(blade)["events"] as Array).size()
	var n := Lore.compact(Game.day() + 90)
	check(n >= 8, "routine work older than two months was folded (%d events)" % n)
	for id in routine + gone_rep:
		var e := Lore.event(str(id))
		eq(str(e.get("kind", "")), "digest", "%s resolves to its digest" % id)
	var dg := Lore.event(str(routine[0]))
	eq(int(dg["data"]["counts"].get("repaired", 0)), 6, "the digest counts the six repairs")
	check(str(dg["text"]).contains("repaired ×6"), "and says so: %s" % dg["text"])
	eq(str(Lore.event(sold).get("kind", "")), "sold", "a sale (provenance) is never folded")
	eq(str(Lore.event(answered).get("kind", "")), "repaired", "work that something happened because of is kept")
	eq(str(Lore.event(linked).get("kind", "")), "note", "an event a causal link points at is kept")
	var hist := Lore.events(Provenance.st(blade)["events"])
	check(hist.any(func(e): return str(e["kind"]) == "digest") and hist.any(func(e): return str(e["id"]) == sold),
		"the blade's story holds the digest and its sale")
	check((Provenance.st(blade)["events"] as Array).size() < before_hist, "its list is shorter (%d → %d)" % [before_hist, (Provenance.st(blade)["events"] as Array).size()])
	var tb_events := Lore.events(tb.get("events", []))
	check(tb_events.any(func(e): return str(e["kind"]) == "lost"), "the lost dagger's tombstone still tells how it was lost")
	check(tb_events.any(func(e): return str(e["kind"]) == "digest"), "and its folded repairs, as a digest")
	var dangling := 0
	for it in ItemRegistry.all_physical(ItemRegistry.ALL, true):
		for id in Provenance.st(it).get("events", []):
			if Lore.event(str(id)).is_empty():
				dangling += 1
	for a in Adv.all().values():
		for id in a.get("lore", []):
			if Lore.event(str(id)).is_empty():
				dangling += 1
	eq(dangling, 0, "no item or person points at a missing event")
	check(save_load("r3_compact"), "saved and loaded")
	eq(str(Lore.event(str(routine[0])).get("kind", "")), "digest", "after loading, folded ids still resolve")


# ------------------------------------------------------------------ 4. causes
func test_death_causes_the_inheritance() -> void:
	fresh_game()
	var ids := Adv.all().keys()
	var dead := Adv.get_a(str(ids[0]))
	var heir := Adv.get_a(str(ids[1]))
	Expeditions.ensure(dead)
	Expeditions.ensure(heir)
	var blade := Items.make("sword_steel", {"quality": 95.0})
	Provenance.forged(blade)
	Provenance.transfer(blade, str(dead["id"]), "sold")
	dead["equipment"]["weapon"] = blade
	heir["equipment"]["weapon"] = Items.make("dagger", {"quality": 30.0})
	heir["status"] = "away"
	var e := {"id": "exp_r3", "dest": "barrow_fields", "party": [dead["id"], heir["id"]], "journal": []}
	Expeditions._kill(e, dead, "the barrow mouth")
	var dev := str(dead.get("death_event", ""))
	check(dev != "" and str(Lore.event(dev)["kind"]) == "death", "the death is one Lore event, kept on the person")
	eq(str(Lore.event(dev).get("roles", {}).get(str(dead["id"]), "")), "fell", "with the role they played")
	Adv.bequeath(dead, [heir["id"]], "barrow_fields", "the Barrow Fields")
	var inh := Lore.of_item(int(blade["uid"])).filter(func(x): return str(x["kind"]) == "inherited")
	check(inh.size() == 1, "the blade was inherited")
	if inh.size() == 1:
		check((inh[0].get("because", []) as Array).has(dev), "because of the death")
		eq(str(inh[0].get("roles", {}).get(str(heir["id"]), "")), "heir", "the heir is named as such")
		check(Lore.why(str(inh[0]["id"])).any(func(x): return str(x["id"]) == dev), "why() walks back to the death")
		check(Lore.consequences(dev).any(func(x): return str(x["id"]) == str(inh[0]["id"])), "consequences() walks forward to it")


func test_indices_agree_with_a_scan() -> void:
	fresh_game()
	_days(20)
	var s := Lore.st()
	for kind in ["forged", "arrived", "departed", "battle"]:
		var scan := 0
		for id in s["order"]:
			if str(s["events"][id].get("kind", "")) == kind:
				scan += 1
		eq(Lore.of_kind(kind).size(), scan, "the %s index matches a full scan (%d)" % [kind, scan])
	for place in ["whisperwood", "brindlewick"]:
		var scan2 := 0
		for id in s["order"]:
			if str(s["events"][id].get("place", "")) == place:
				scan2 += 1
		eq(Lore.of_place(place).size(), scan2, "the %s place index matches a full scan" % place)


# ------------------------------------------------------------------ 5. seeded streams
func test_streams_are_independent() -> void:
	fresh_game()
	var before := str(Game.state.get("rng", {}).get("expeditions", ""))
	for i in 25:
		Dice.roll("1d20")
	eq(str(Game.state.get("rng", {}).get("expeditions", "")), before, "the smith's dice do not move the expeditions' luck")
	check(str(Game.state["rng"].get("crafting", "")) != "", "they draw from their own stream")


func _fingerprint() -> String:
	var st := Game.state.duplicate(true)
	return JSON.stringify(st, "", true)


func test_a_seeded_campaign_replays_bit_for_bit() -> void:
	fresh_game("journeyman", 4321)
	_days(25)
	var a := _fingerprint()
	fresh_game("journeyman", 4321)
	_days(25)
	var b := _fingerprint()
	check(a == b, "the same seed gives the same 25 days (%d chars)" % a.length())
	fresh_game("journeyman", 4321)
	_days(12)
	check(save_load("r3_replay"), "saved on day 13 and loaded")
	_days(13)
	var c := _fingerprint()
	if not check(c == a, "save → load → continue gives exactly the uninterrupted campaign"):
		var ja: Dictionary = JSON.parse_string(a)
		var jc: Dictionary = JSON.parse_string(c)
		var diff := []
		for k in ja:
			if JSON.stringify(ja[k], "", true) != JSON.stringify(jc.get(k), "", true):
				diff.append(str(k))
		note("differing top-level keys: %s" % str(diff))
