## Canonical v1.7 §11 (#70) — Barnaby's Ironfront introduction: a fixed teaching match that following Barnaby's
## suggestions wins, its welcome purse paid once and no cards granted (replayable without rewards); the lent loaner deck;
## Barnaby buying spare cards (never lent ones) below his selling prices; cards found on expeditions owned by their
## finder and sold to Barnaby's shelf (a hireling's find is the smith's); the Field Manual explaining every card.
extends SuiteCase

const SMOKE := ["test_teaching_match_is_won_by_following_barnaby", "test_selling_and_lent_cards"]


func _teaching(seed_: int) -> Dictionary:
	var d: Dictionary = Ironfront.data().get("starter_deck", {})
	var m := Ironfront.new_match(d, Ironfront.data()["teaching_deck"], "standard", seed_, {"names": ["Brannoc", "Barnaby"], "opp": "barnaby",
		"ai": [{}, {"skill": 0.3, "bluff": 0.0, "greed": 0.8}], "tutorial": true})
	var guard := 0
	while not m["over"] and guard < 300:
		guard += 1
		var side := int(m["turn"])
		var mv: Dictionary = Ironfront.suggest(m, 0).get("move", {}) if side == 0 else Ironfront.ai_move(m, 1)
		if mv.is_empty() or not Ironfront.apply(m, side, mv):
			Ironfront.apply(m, side, {"type": "pass"})
	return m


func test_teaching_match_is_won_by_following_barnaby() -> void:
	fresh_game()
	var m := _teaching(Ironfront.TEACHING_SEED)
	eq(int(m["winner"]), 0, "the teaching deal is won by following Barnaby's suggestions")
	# a real game, not a script: passing every turn loses the same deal, and on other deals the advice still wins often
	var mp := Ironfront.new_match(Ironfront.data()["starter_deck"], Ironfront.data()["teaching_deck"], "standard", Ironfront.TEACHING_SEED,
		{"tutorial": true, "ai": [{}, {"skill": 0.3, "bluff": 0.0, "greed": 0.8}]})
	var guard := 0
	while not mp["over"] and guard < 300:
		guard += 1
		var sd := int(mp["turn"])
		var mv: Dictionary = {"type": "pass"} if sd == 0 else Ironfront.ai_move(mp, 1)
		if mv.is_empty() or not Ironfront.apply(mp, sd, mv):
			Ironfront.apply(mp, sd, {"type": "pass"})
	eq(int(mp["winner"]), 1, "passing every turn loses the same deal — the win is earned")
	var wins := 0
	for s in range(1, 41):
		if int(_teaching(s)["winner"]) == 0:
			wins += 1
	note("following the suggestions on 40 other deals: %d won" % wins)
	check(wins >= 16, "the suggestions are real advice on any deal (%d of 40 won against the teaching box)" % wins)
	# every suggestion carries a plain reason
	var m2 := Ironfront.new_match(Ironfront.data()["starter_deck"], Ironfront.data()["teaching_deck"], "standard", Ironfront.TEACHING_SEED,
		{"tutorial": true, "ai": [{}, {"skill": 0.3}]})
	m2["turn"] = 0
	var sug := Ironfront.suggest(m2, 0)
	check(str(sug.get("why", "")).length() > 20 and not sug.get("move", {}).is_empty(), "a suggestion names a move and why: %s" % str(sug.get("why", "")).left(90))
	var rs := int(m2["ai_rs"])
	Ironfront.suggest(m2, 0)
	eq(int(m2["ai_rs"]), rs, "asking for a suggestion never changes the game's dice")


func test_teaching_rewards_once_and_no_cards() -> void:
	fresh_game()
	var col := JSON.stringify(Ironfront.st()["collection"])
	var g0 := Game.gold()
	var r1 := Ironfront.finish_reward(_teaching(Ironfront.TEACHING_SEED))
	eq(int(r1["gold"]), 10, "the first teaching win: Barnaby's 10 g welcome")
	check(bool(Ironfront.st()["tutorial_done"]), "the introduction is done")
	var r2 := Ironfront.finish_reward(_teaching(Ironfront.TEACHING_SEED))
	eq(int(r2["gold"]), 0, "a replay pays nothing")
	eq(Game.gold(), g0 + 10, "10 g in all")
	eq(JSON.stringify(Ironfront.st()["collection"]), col, "the teaching match never grants a card")
	eq(int(Ironfront.st().get("matches", 0)), 0, "nor counts as a match on the record")


func test_selling_and_lent_cards() -> void:
	fresh_game()
	var lent: Dictionary = Ironfront.st()["lent"]
	var want: Dictionary = Ironfront.data()["starter_deck"]["cards"]
	check(lent.size() == want.size() and want.keys().all(func(k): return int(lent.get(k, 0)) == int(want[k])), "the loaner deck is lent")
	check(Ironfront.lent("tiger") == 0 and Ironfront.owned("tiger") == 0, "and it is not the strongest collection (no Tiger)")
	eq(Ironfront.spare("sherman"), 0, "lent Shermans cannot be sold")
	eq(Ironfront.sell_card("sherman"), 0, "…Barnaby refuses")
	var spare := Ironfront.spare("rifle_company")
	check(spare > 0, "the smith's own extra cards are spare (%d Rifle Companies)" % spare)
	var g0 := Game.gold()
	var p := Ironfront.sell_card("rifle_company")
	check(p > 0 and Game.gold() == g0 + p, "sold one for %d g" % p)
	eq(Ironfront.spare("rifle_company"), spare - 1, "one fewer")
	eq(Game.state["ledger"].back().get("party", ""), "barnaby", "Barnaby paid it (a real payer)")
	for r in ["common", "uncommon", "rare"]:
		var id := Ironfront.random_card(r)
		check(Ironfront.single_price(id) > Ironfront.sell_price(id), "%s: Barnaby buys below his own price (%d < %d)" % [r, Ironfront.sell_price(id), Ironfront.single_price(id)])
	# an older save without the loan record: what it still holds of the loaner deck is lent
	Game.state["ironfront"].erase("lent")
	eq(Ironfront.st()["lent"].get("sherman", 0), mini(3, Ironfront.owned("sherman")), "an older save: the loaner cards still held are lent")


func test_found_cards_belong_to_their_finder() -> void:
	fresh_game()
	var a: Dictionary = Adv.in_town()[0]
	var col := Ironfront.collection_size()
	var id := Ironfront.card_found(a, false, "rare")
	check(id != "" and (a["ironfront_cards"] as Array).has(id), "an adventurer's find is theirs (%s)" % id)
	eq(Ironfront.collection_size(), col, "not the smith's")
	var ag := int(a["gold"])
	Ironfront.on_day()
	check((a["ironfront_cards"] as Array).is_empty() and int(a["gold"]) == ag + Ironfront.sell_price(id), "they sell it to Barnaby, paid into their purse")
	var shelf := Ironfront.found_shelf()
	check(shelf.size() == 1 and str(shelf[0]["id"]) == id and str(shelf[0]["from"]) == str(a["id"]), "it is on Barnaby's found shelf, with its finder")
	Game.state["gold"] = 5000
	check(Ironfront.buy_found(0), "the smith buys it")
	eq(Ironfront.collection_size(), col + 1, "one card more")
	check(Ironfront.found_shelf().is_empty() and not Ironfront.buy_found(0), "and it is gone from the shelf (no second copy)")
	var h := {"id": "hire_x", "name": "Borin"}
	var hid := Ironfront.card_found(h, true)
	eq(Ironfront.collection_size(), col + 2, "a hireling's find comes home in the smith's haul (%s)" % hid)
	# the shelf keeps the newest SHELF_MAX
	for i in Ironfront.SHELF_MAX + 3:
		Ironfront.card_found(a, false, "common")
	Ironfront.on_day()
	eq(Ironfront.found_shelf().size(), Ironfront.SHELF_MAX, "the shelf holds %d" % Ironfront.SHELF_MAX)


func test_field_manual_explains_every_card() -> void:
	fresh_game()
	var seen := {}
	for les in Ironfront.lessons():
		for id in les["cards"]:
			seen[id] = int(seen.get(id, 0)) + 1
	eq(seen.size(), Ironfront.all_cards().size(), "every defined card is in the manual (%d)" % seen.size())
	check(seen.values().all(func(n): return int(n) == 1), "each in exactly one lesson")
	check(Ironfront.all_cards().all(func(c): return Ironfront.explain(str(c["id"])).length() > 30), "each has Barnaby's explanation")
	eq(Ironfront.lessons_open(), 1, "a new smith: lesson 1 (the loaner deck)")
	Ironfront.visit_table()
	eq(Ironfront.lessons_open(), 1, "no more before the teaching match")
	Ironfront.finish_reward(_teaching(Ironfront.TEACHING_SEED))
	eq(Ironfront.lessons_open(), 2, "after it: lesson 2")
	Ironfront.visit_table()
	Ironfront.visit_table()
	eq(Ironfront.lessons_open(), 2, "the first visit after it opens nothing more, nor a second visit the same day")
	days(1)
	Ironfront.visit_table()
	eq(Ironfront.lessons_open(), 3, "a new day at the table: one more lesson")
	check(not Ironfront.owned("tiger2"), "explaining a card never grants it")
