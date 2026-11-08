## Scenario E — Ironfront: a complete match against the AI, card rewards, a deck change, persistence.
extends SuiteCase

const SMOKE := ["test_match_rewards_deck_persist"]


func test_match_rewards_deck_persist() -> void:
	if not has_system("ironfront"):
		skip("Ironfront not in this build")
		return
	var st: Dictionary = Ironfront.st()
	var cards0 := Ironfront.collection_size()
	var deck: Dictionary = Ironfront.active_deck()
	check(Ironfront.validate_deck(deck).is_empty(), "the starter deck is valid")
	var opp := Ironfront.opponent("jory")
	var m := Ironfront.new_match(deck, opp.get("deck", deck), "standard", 4242, {"opp": "jory"})
	var guard := 0
	while not bool(m.get("over", false)) and guard < 400:
		var side := int(m.get("turn", 0))
		var mv := Ironfront.ai_move(m, side)
		if not Ironfront.apply(m, side, mv):
			Ironfront.apply(m, side, {"type": "pass"})
		guard += 1
	check(bool(m.get("over", false)) and int(m.get("winner", -1)) in [0, 1, 2], "the match is played to the end (%d moves)" % guard)
	var rw := Ironfront.finish_reward(m)
	check(rw.has("result") and rw.has("gold"), "rewards are settled (%s)" % str(rw.get("result", "")))
	check(Ironfront.collection_size() >= cards0, "the collection never shrinks")
	# a deck change persists
	var d2: Dictionary = deck.duplicate(true)
	d2["name"] = "Suite deck"
	var idx := Ironfront.save_deck(-1, d2)
	check(idx >= 0, "a new deck is saved")
	Ironfront.set_active(idx)
	var won := Ironfront.total_wins()
	check(save_load("suite_ironfront"), "save and load")
	eq(str(Ironfront.active_deck().get("name", "")), "Suite deck", "the active deck survives")
	eq(Ironfront.total_wins(), won, "the win record survives")


func test_blitzkrieg() -> void:
	if not has_system("ironfront"):
		skip("Ironfront not in this build")
		return
	var deck: Dictionary = Ironfront.active_deck()
	var res := Ironfront.simulate(deck, deck, "blitz", 7, {})
	check(not res.is_empty(), "a Blitzkrieg match simulates to an end (%s)" % str(res.get("winner", res.get("result", "?"))))
