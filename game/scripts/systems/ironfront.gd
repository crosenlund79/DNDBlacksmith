## Ironfront — Barnaby's war-room card game: collection, decks, shop, rewards and a pure match engine.
## EN: The match engine is static and UI-free so tests, the panel and the AI all drive the same rules:
##       var m := Ironfront.new_match(deck_a, deck_b, "standard"|"blitz", seed)
##       Ironfront.legal_moves(m, side) -> [{type: pass|commander|play, uid?, target?}]
##       Ironfront.apply(m, side, move) -> bool        (side 0 = the player, 1 = the opponent)
##       Ironfront.ai_move(m, side) -> move
##       Ironfront.finish_reward(m) -> {cards, gold}    (applies to Game.state once)
##     A match is a plain Dictionary (JSON-like, deep-copyable); m["events"] collects animation
##     events for the board (the UI drains it) and m["log"] the human-readable play log.
##     Persistent state lives in Game.state["ironfront"] (created lazily): collection {card: count},
##     decks [{name, faction, commander, cards {id: n}}], active, record {opp: {w, l, d}}, unlocked [opp].
##     Other systems award cards with Ironfront.grant_card(id, source) and Ironfront.random_card(rarity).
## DA: Ironfront — kortspillet i Barnabys kælder. Kampmotoren er statisk og uden brugerflade.
class_name Ironfront
extends RefCounted

const ROWS := ["inf", "arm", "air"]
const ROW_NAMES := {"inf": "Infantry", "arm": "Armour", "air": "Air"}
const RARITY_NAMES := {"common": "Common", "uncommon": "Uncommon", "rare": "Rare", "special": "Special"}
const LOG_CAP := 80

static var _index := {}


# =========================================================================== data
static func data() -> Dictionary:
	var d: Variant = DB.extra("ironfront")
	return d if d is Dictionary else {}


static func card(id: String) -> Dictionary:
	if _index.is_empty():
		for c: Dictionary in data().get("cards", []):
			_index[str(c["id"])] = c
	return _index.get(id, {})


static func all_cards() -> Array:
	return data().get("cards", [])


static func commanders(faction := "") -> Array:
	return data().get("commanders", []).filter(func(c): return faction == "" or c["faction"] == faction)


static func commander(id: String) -> Dictionary:
	for c: Dictionary in data().get("commanders", []):
		if c["id"] == id:
			return c
	return {}


static func opponents() -> Array:
	return data().get("opponents", [])


static func opponent(id: String) -> Dictionary:
	for o: Dictionary in opponents():
		if o["id"] == id:
			return o
	return {}


static func has_ability(c: Dictionary, k: String) -> bool:
	for a: Dictionary in c.get("abilities", []):
		if a["k"] == k:
			return true
	return false


static func ability(c: Dictionary, k: String) -> Dictionary:
	for a: Dictionary in c.get("abilities", []):
		if a["k"] == k:
			return a
	return {}


## Human-readable ability lines for a card (hover zoom, collection).
static func ability_text(c: Dictionary) -> String:
	var lines: Array[String] = []
	if c.get("type", "") == "tactic":
		lines.append(str(data().get("rules", {}).get("tactics", {}).get(str(c.get("effect", "")), "")))
		if c.get("effect", "") == "weather":
			lines.append("Row: " + str(ROW_NAMES.get(str(c.get("row_target", "")), "")))
		if int(c.get("draw", 0)) > 0:
			lines.append("Then draw a card.")
	for a: Dictionary in c.get("abilities", []):
		var k: String = a["k"]
		var t: String = str(data().get("rules", {}).get("abilities", {}).get(k, k))
		t = t.replace(" N ", " %d " % int(a.get("n", 0))).replace(" N", " %d" % int(a.get("n", 0)))
		if a.has("row"):
			t += " (%s)" % ROW_NAMES.get(str(a["row"]), "")
		lines.append(t)
	if c.get("special", false):
		lines.append("Found only through merchants or exploration.")
	return "\n".join(lines)


# =========================================================================== persistent state
static func st() -> Dictionary:
	if not Game.state.has("ironfront") or not (Game.state["ironfront"] is Dictionary):
		Game.state["ironfront"] = _new_state()
	var s: Dictionary = Game.state["ironfront"]
	for k in ["collection", "record"]:
		if not s.has(k):
			s[k] = {}
	for k in ["decks", "unlocked", "found"]:
		if not s.has(k):
			s[k] = []
	if not s.has("active"):
		s["active"] = 0
	if not s.has("lent"):
		s["lent"] = _lent_for(s)   # v1.7: Barnaby's loaner deck is lent (older saves: what of it is still held)
	if not s.has("shelf"):
		s["shelf"] = []
	return s


## The loaner deck's cards (data "starter_deck"), as far as the collection still holds them.
static func _lent_for(s: Dictionary) -> Dictionary:
	var out := {}
	var col: Dictionary = s.get("collection", {})
	var starter: Dictionary = data().get("starter_deck", {}).get("cards", {})
	for id: String in starter:
		var n := mini(int(starter[id]), int(col.get(id, 0)))
		if n > 0:
			out[id] = n
	return out


static func _new_state() -> Dictionary:
	var col := {}
	var starter: Dictionary = data().get("starter_deck", {})
	for id: String in starter.get("cards", {}):
		col[id] = int(col.get(id, 0)) + int(starter["cards"][id])
	var extra: Dictionary = data().get("starter_extra", {})
	for id: String in extra:
		col[id] = int(col.get(id, 0)) + int(extra[id])
	var unlocked: Array = []
	for o: Dictionary in opponents():
		if str(o.get("unlock", "")) == "":
			unlocked.append(o["id"])
	return {"collection": col, "decks": [starter.duplicate(true)] if not starter.is_empty() else [], "active": 0,
		"record": {}, "unlocked": unlocked, "found": [], "matches": 0, "tutorial_done": false}


static func owned(id: String) -> int:
	return int(st()["collection"].get(id, 0))


static func collection_size() -> int:
	var n := 0
	for id: String in st()["collection"]:
		n += int(st()["collection"][id])
	return n


## Adds one copy of a card to the player's collection. source: "win:jory", "pack", "shop", "merchant",
## "expedition", "event" … Returns false for unknown ids.
static func grant_card(card_id: String, source: String = "") -> bool:
	var c := card(card_id)
	if c.is_empty():
		return false
	var col: Dictionary = st()["collection"]
	col[card_id] = int(col.get(card_id, 0)) + 1
	var found: Array = st()["found"]
	found.append({"id": card_id, "source": source, "day": Game.state.get("day", 1)})
	while found.size() > 60:
		found.pop_front()
	return true


## A random card id. rarity "" draws with the general odds (specials included, rarely);
## "common" | "uncommon" | "rare" | "special" picks within that rarity.
static func random_card(rarity := "") -> String:
	var r := rarity
	if r == "":
		var x := randf()
		r = "common" if x < 0.6 else "uncommon" if x < 0.87 else "rare" if x < 0.97 else "special"
	var pool := all_cards().filter(func(c): return c["rarity"] == r)
	if pool.is_empty():
		pool = all_cards().filter(func(c): return not c.get("special", false))
	if pool.is_empty():
		return ""
	return str(pool[randi() % pool.size()]["id"])


static func _weighted_rarity(odds: Dictionary) -> String:
	var x := randf()
	var acc := 0.0
	for k in ["common", "uncommon", "rare"]:
		acc += float(odds.get(k, 0.0))
		if x < acc:
			return k
	return "rare"


# ---------------------------------------------------------------- decks
static func deck_rules() -> Dictionary:
	return data().get("deck_rules", {"min": 22, "max": 30, "min_units": 14})


static func deck_size(deck: Dictionary) -> int:
	var n := 0
	for id: String in deck.get("cards", {}):
		n += int(deck["cards"][id])
	return n


static func max_copies(id: String) -> int:
	return int(deck_rules().get("copies", {}).get(str(card(id).get("rarity", "common")), 1))


## Empty array = valid. With a collection, counts may not exceed the copies owned.
static func validate_deck(deck: Dictionary, collection: Dictionary = {}) -> Array:
	var errs: Array = []
	var rules := deck_rules()
	var faction: String = deck.get("faction", "")
	if not data().get("factions", {}).has(faction) or faction == "neutral":
		errs.append("Choose a faction.")
	var n := 0
	var units := 0
	for id: String in deck.get("cards", {}):
		var k := int(deck["cards"][id])
		if k <= 0:
			continue
		var c := card(id)
		if c.is_empty():
			errs.append("Unknown card '%s'." % id)
			continue
		n += k
		if c["type"] == "unit":
			units += k
		if c["faction"] != faction and c["faction"] != "neutral":
			errs.append("%s does not belong to this faction." % c["name"])
		if k > max_copies(id):
			errs.append("At most %d of %s." % [max_copies(id), c["name"]])
		if not collection.is_empty() and k > int(collection.get(id, 0)):
			errs.append("You own only %d of %s." % [int(collection.get(id, 0)), c["name"]])
	if n < int(rules["min"]):
		errs.append("Too few cards: %d (minimum %d)." % [n, int(rules["min"])])
	if n > int(rules["max"]):
		errs.append("Too many cards: %d (maximum %d)." % [n, int(rules["max"])])
	if units < int(rules.get("min_units", 0)):
		errs.append("Too few units: %d (minimum %d)." % [units, int(rules.get("min_units", 0))])
	var cm := commander(str(deck.get("commander", "")))
	if cm.is_empty() or cm["faction"] != faction:
		errs.append("Choose a commander of this faction.")
	return errs


static func decks() -> Array:
	return st()["decks"]


## Stores (or appends when idx is out of range) a player deck. Returns its index.
static func save_deck(idx: int, deck: Dictionary) -> int:
	var ds: Array = st()["decks"]
	var d := deck.duplicate(true)
	var clean := {}
	for id: String in d.get("cards", {}):
		if int(d["cards"][id]) > 0:
			clean[id] = int(d["cards"][id])
	d["cards"] = clean
	if idx >= 0 and idx < ds.size():
		ds[idx] = d
		return idx
	ds.append(d)
	return ds.size() - 1


static func delete_deck(idx: int) -> void:
	var ds: Array = st()["decks"]
	if idx >= 0 and idx < ds.size() and ds.size() > 1:
		ds.remove_at(idx)
		st()["active"] = clampi(int(st()["active"]), 0, ds.size() - 1)


static func active_deck() -> Dictionary:
	var ds: Array = st()["decks"]
	if ds.is_empty():
		return {}
	return ds[clampi(int(st()["active"]), 0, ds.size() - 1)]


static func set_active(idx: int) -> void:
	st()["active"] = clampi(idx, 0, maxi(0, decks().size() - 1))


static func opponent_deck(opp_id: String) -> Dictionary:
	return opponent(opp_id).get("deck", {})


# ---------------------------------------------------------------- opponents and records
static func is_unlocked(opp_id: String) -> bool:
	var o := opponent(opp_id)
	if o.is_empty():
		return false
	if st()["unlocked"].has(opp_id):
		return true
	var u: String = o.get("unlock", "")
	if u == "":
		return true
	if u.begins_with("wins:"):
		return total_wins() >= int(u.substr(5))
	if u.begins_with("beat:"):
		return int(record(u.substr(5)).get("w", 0)) > 0
	return false


static func unlock_hint(opp_id: String) -> String:
	var u: String = opponent(opp_id).get("unlock", "")
	if u.begins_with("wins:"):
		return "Win %d match(es) at Barnaby's table." % int(u.substr(5))
	if u.begins_with("beat:"):
		return "Beat %s first." % opponent(u.substr(5)).get("name", u.substr(5))
	return ""


static func record(opp_id: String) -> Dictionary:
	var r: Dictionary = st()["record"]
	if not r.has(opp_id):
		r[opp_id] = {"w": 0, "l": 0, "d": 0}
	return r[opp_id]


static func total_wins() -> int:
	var n := 0
	for k: String in st()["record"]:
		n += int(st()["record"][k].get("w", 0))
	return n


static func _refresh_unlocks() -> Array:
	var newly: Array = []
	for o: Dictionary in opponents():
		if not st()["unlocked"].has(o["id"]) and is_unlocked(o["id"]):
			st()["unlocked"].append(o["id"])
			newly.append(o["id"])
	return newly


# ---------------------------------------------------------------- shop
static func shop_cfg() -> Dictionary:
	return data().get("shop", {})


static func single_price(id: String) -> int:
	return int(shop_cfg().get("single_price", {}).get(str(card(id).get("rarity", "common")), 30))


## Today's singles on Barnaby's shelf (rotates daily; specials never appear).
static func shop_singles(day := -1) -> Array:
	var d := day if day >= 0 else int(Game.state.get("day", 1))
	var pool := all_cards().filter(func(c): return not c.get("special", false))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 * d + 101
	var out: Array = []
	var guard := 0
	while out.size() < int(shop_cfg().get("sell_singles", 6)) and guard < 200 and not pool.is_empty():
		guard += 1
		var id: String = pool[rng.randi() % pool.size()]["id"]
		if not out.has(id):
			out.append(id)
	return out


## Buys a pack; returns the card ids (empty when the player cannot afford it).
static func buy_pack() -> Array:
	var price := int(shop_cfg().get("pack_price", 60))
	if not Game.can_afford(price):
		return []
	Game.add_gold(-price, "ironfront", "Ironfront pack", "ironfront")
	var ids: Array = []
	for i in int(shop_cfg().get("pack_size", 5)):
		var r := _weighted_rarity(shop_cfg().get("pack_odds", {}))
		if i == int(shop_cfg().get("pack_size", 5)) - 1 and r == "common":
			r = "uncommon"     # one guaranteed uncommon or better
		var id := random_card(r)
		grant_card(id, "pack")
		ids.append(id)
	return ids


static func buy_single(id: String) -> bool:
	var c := card(id)
	if c.is_empty() or c.get("special", false):
		return false
	var price := single_price(id)
	if not Game.can_afford(price):
		return false
	Game.add_gold(-price, "ironfront", "Ironfront card: " + str(c["name"]), "ironfront")
	grant_card(id, "shop")
	return true


# =========================================================================== match engine
static func _r(m: Dictionary, key := "rs") -> int:
	var v := (int(m.get(key, 1)) * 1103515245 + 12345) % 2147483648
	m[key] = v
	return v >> 7


static func _ri(m: Dictionary, n: int, key := "rs") -> int:
	return 0 if n <= 0 else _r(m, key) % n


static func _rf(m: Dictionary, key := "ai_rs") -> float:
	return float(_r(m, key) % 100000) / 100000.0


static func _shuffle(m: Dictionary, arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := _ri(m, i + 1)
		var t: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = t


static func is_blitz(m: Dictionary) -> bool:
	return m.get("mode", "standard") == "blitz"


## mode "standard" (best of three) or "blitz" (one fast round). opts: names [a, b], opp, ai [{}, {}], tutorial.
static func new_match(deck_a: Dictionary, deck_b: Dictionary, mode := "standard", seed := 1, opts: Dictionary = {}) -> Dictionary:
	var m := {"mode": mode, "seed": seed, "rs": (absi(seed) * 7919 + 17) % 2147483648, "ai_rs": (absi(seed) * 104729 + 3) % 2147483648,
		"round": 1, "turn": 0, "over": false, "winner": -1, "turns": 0, "next_uid": 1,
		"weather": {"inf": false, "arm": false, "air": false}, "sides": [], "log": [], "events": [], "rounds": [],
		"max_rounds": 1 if mode == "blitz" else 3, "opp": str(opts.get("opp", "")), "tutorial": bool(opts.get("tutorial", false)),
		"ai": opts.get("ai", [{}, {}])}
	var names: Array = opts.get("names", ["You", "Opponent"])
	var hand := int(data().get("blitz", {}).get("hand", 8)) if mode == "blitz" else 10
	for i in 2:
		var dk: Dictionary = deck_a if i == 0 else deck_b
		var faction: String = dk.get("faction", "allies")
		var cmd: String = dk.get("commander", "")
		if commander(cmd).is_empty():
			var cs := commanders(faction)
			cmd = cs[0]["id"] if not cs.is_empty() else ""
		var s := {"name": str(names[i]) if i < names.size() else "Side %d" % i, "faction": faction, "commander": cmd,
			"cmd_used": false, "deck": [], "hand": [], "rows": {"inf": [], "arm": [], "air": []}, "discard": [],
			"passed": false, "wins": 0, "boost": {"inf": 0, "arm": 0, "air": 0}, "revealed": [], "reveal_all": false,
			"guard_inf": false, "plays": 0}
		for id: String in dk.get("cards", {}):
			var c := card(id)
			if c.is_empty():
				continue
			for k in int(dk["cards"][id]):
				s["deck"].append({"uid": int(m["next_uid"]), "id": id, "str": int(c.get("str", 0)), "shield": false})
				m["next_uid"] = int(m["next_uid"]) + 1
		m["sides"].append(s)
	for i in 2:
		_shuffle(m, m["sides"][i]["deck"])
		for k in hand:
			_draw(m, i, false)
	m["turn"] = _ri(m, 2)
	m["first"] = m["turn"]
	_log(m, "%s %s." % [m["sides"][m["turn"]]["name"], "moves first" if mode != "blitz" else "strikes first in the Blitzkrieg"])
	return m


static func _log(m: Dictionary, t: String) -> void:
	if m.has("_sim"):
		return
	var lg: Array = m["log"]
	lg.append(t)
	while lg.size() > LOG_CAP:
		lg.pop_front()


static func _ev(m: Dictionary, e: Dictionary) -> void:
	if m.has("_sim"):
		return
	m["events"].append(e)


static func _draw(m: Dictionary, side: int, log_it := true) -> bool:
	var s: Dictionary = m["sides"][side]
	if s["deck"].is_empty():
		return false
	var c: Dictionary = s["deck"].pop_back()
	s["hand"].append(c)
	_ev(m, {"k": "draw", "side": side, "uid": c["uid"]})
	if log_it:
		_log(m, "%s draws a card." % s["name"])
	return true


static func cname(c: Dictionary) -> String:
	return str(card(str(c.get("id", ""))).get("name", c.get("id", "?")))


# ---------------------------------------------------------------- strength
static func _passive(c: Dictionary, k: String) -> int:
	if c.get("decoy", false):
		return 0
	return int(ability(card(str(c["id"])), k).get("n", 0)) if has_ability(card(str(c["id"])), k) else 0


static func eff(m: Dictionary, side: int, row: String, c: Dictionary) -> int:
	if c.get("decoy", false):
		return 0
	var cd := card(str(c["id"]))
	var s := int(c["str"])
	if has_ability(cd, "elite"):
		return s
	var sd: Dictionary = m["sides"][side]
	var guarded: bool = has_ability(cd, "entrench") or (row == "inf" and sd.get("guard_inf", false))
	if m["weather"].get(row, false) and not guarded:
		s = mini(s, 1)
	s += int(sd["boost"].get(row, 0))
	for o: Dictionary in sd["rows"][row]:
		if o["uid"] != c["uid"]:
			s += _passive(o, "rally")
	var ca := _passive(c, "combined")
	if ca > 0:
		for r: String in ROWS:
			if r != row and not sd["rows"][r].filter(func(x): return not x.get("decoy", false)).is_empty():
				s += ca
				break
	return maxi(s, 0)


static func row_score(m: Dictionary, side: int, row: String) -> int:
	var t := 0
	for c: Dictionary in m["sides"][side]["rows"][row]:
		t += eff(m, side, row, c)
	return t


static func score(m: Dictionary, side: int) -> int:
	var t := 0
	for r: String in ROWS:
		t += row_score(m, side, r)
	return t


static func _row_of(m: Dictionary, side: int, uid: int) -> String:
	for r: String in ROWS:
		for c: Dictionary in m["sides"][side]["rows"][r]:
			if int(c["uid"]) == uid:
				return r
	return ""


# ---------------------------------------------------------------- damage
static func _immune(c: Dictionary) -> bool:
	return has_ability(card(str(c["id"])), "elite") or c.get("decoy", false)


## Hits a unit on the board; returns true when it was destroyed.
static func _hit(m: Dictionary, side: int, c: Dictionary, n: int, why: String) -> bool:
	if _immune(c) or n <= 0:
		return false
	if c.get("shield", false):
		c["shield"] = false
		_ev(m, {"k": "block", "side": side, "uid": c["uid"]})
		_log(m, "  %s's %s is dug in and shrugs off the %s." % [m["sides"][side]["name"], cname(c), why])
		return false
	c["str"] = int(c["str"]) - n
	_ev(m, {"k": "dmg", "side": side, "uid": c["uid"], "n": n})
	if int(c["str"]) <= 0:
		_destroy(m, side, c)
		_log(m, "  %s hits %s's %s for %d — destroyed." % [why.capitalize(), m["sides"][side]["name"], cname(c), n])
		return true
	_log(m, "  %s hits %s's %s for %d." % [why.capitalize(), m["sides"][side]["name"], cname(c), n])
	return false


static func _destroy(m: Dictionary, side: int, c: Dictionary) -> void:
	var s: Dictionary = m["sides"][side]
	for r: String in ROWS:
		var row: Array = s["rows"][r]
		var i := row.find(c)
		if i >= 0:
			row.remove_at(i)
			break
	_reset(c)
	s["discard"].append(c)
	_ev(m, {"k": "destroy", "side": side, "uid": c["uid"]})


static func _reset(c: Dictionary) -> void:
	c["str"] = int(card(str(c["id"])).get("str", 0))
	c["shield"] = false
	c.erase("decoy")


static func _strongest(m: Dictionary, side: int, row: String, weakest := false) -> Dictionary:
	var best: Dictionary = {}
	var bv := 0
	for c: Dictionary in m["sides"][side]["rows"][row]:
		if _immune(c):
			continue
		var v := eff(m, side, row, c)
		if best.is_empty() or (v > bv if not weakest else v < bv):
			best = c
			bv = v
	return best


# ---------------------------------------------------------------- moves
static func legal_moves(m: Dictionary, side: int) -> Array:
	if m.get("over", false) or int(m["turn"]) != side:
		return []
	var s: Dictionary = m["sides"][side]
	var out: Array = [{"type": "pass"}]
	if not s["cmd_used"]:
		out.append({"type": "commander"})
	var own_units: Array = []
	for r: String in ROWS:
		for c: Dictionary in s["rows"][r]:
			if not c.get("decoy", false) and not has_ability(card(str(c["id"])), "elite"):
				own_units.append(int(c["uid"]))
	for c: Dictionary in s["hand"]:
		var cd := card(str(c["id"]))
		if cd.get("effect", "") == "decoy":
			for u: int in own_units:
				out.append({"type": "play", "uid": int(c["uid"]), "target": u})
		else:
			out.append({"type": "play", "uid": int(c["uid"])})
	return out


static func _hand_card(s: Dictionary, uid: int) -> Dictionary:
	for c: Dictionary in s["hand"]:
		if int(c["uid"]) == uid:
			return c
	return {}


static func apply(m: Dictionary, side: int, move: Dictionary) -> bool:
	if m.get("over", false) or int(m["turn"]) != side:
		return false
	var s: Dictionary = m["sides"][side]
	match str(move.get("type", "")):
		"pass":
			s["passed"] = true
			_ev(m, {"k": "pass", "side": side})
			_log(m, "%s passes." % s["name"])
		"commander":
			if s["cmd_used"]:
				return false
			s["cmd_used"] = true
			_commander(m, side)
		"play":
			var c := _hand_card(s, int(move.get("uid", -1)))
			if c.is_empty():
				return false
			var cd := card(str(c["id"]))
			if cd.get("effect", "") == "decoy":
				var tr := _row_of(m, side, int(move.get("target", -1)))
				if tr == "":
					return false
			s["hand"].erase(c)
			s["revealed"].erase(c["uid"])
			if cd["type"] == "unit":
				_play_unit(m, side, c, str(cd["row"]), true)
				s["plays"] = int(s["plays"]) + 1
			else:
				_play_tactic(m, side, c, move)
				s["plays"] = int(s["plays"]) + 1
		_:
			return false
	m["turns"] = int(m["turns"]) + 1
	_after_move(m, side)
	return true


static func _play_unit(m: Dictionary, side: int, c: Dictionary, row: String, abilities: bool) -> void:
	var s: Dictionary = m["sides"][side]
	var o: Dictionary = m["sides"][1 - side]
	var cd := card(str(c["id"]))
	var blitz := is_blitz(m)
	var bz: Dictionary = data().get("blitz", {})
	c["shield"] = has_ability(cd, "entrench")
	if blitz and abilities and int(s["plays"]) < int(bz.get("momentum_plays", 2)) and not has_ability(cd, "elite"):
		c["str"] = int(c["str"]) + int(bz.get("momentum", 2))
		_ev(m, {"k": "boost", "side": side, "uid": c["uid"], "n": int(bz.get("momentum", 2))})
	s["rows"][row].append(c)
	_ev(m, {"k": "play", "side": side, "uid": c["uid"], "row": row, "id": c["id"]})
	if abilities:
		_log(m, "%s deploys %s (%s, %d)." % [s["name"], cd["name"], ROW_NAMES[row], int(c["str"])])
	else:
		_log(m, "  %s joins %s's %s." % [cd["name"], s["name"], ROW_NAMES[row]])
		return
	var has_assault := false
	for a: Dictionary in cd.get("abilities", []):
		var n := int(a.get("n", 0))
		match str(a["k"]):
			"spotter":
				var hidden: Array = o["hand"].filter(func(x): return not o["revealed"].has(x["uid"]))
				for i in mini(2, hidden.size()):
					var pick: Dictionary = hidden[_ri(m, hidden.size())]
					hidden.erase(pick)
					o["revealed"].append(pick["uid"])
				_ev(m, {"k": "reveal", "side": 1 - side})
				_log(m, "  The spotter reports two of %s's cards." % o["name"])
			"artillery":
				var t := _strongest(m, 1 - side, str(a.get("row", row)))
				if not t.is_empty():
					_hit(m, 1 - side, t, n, "artillery")
			"barrage":
				for t: Dictionary in o["rows"][str(a.get("row", row))].duplicate():
					_hit(m, 1 - side, t, n, "barrage")
			"supply":
				_draw(m, side)
			"reinforce":
				var g: String = a.get("group", cd.get("group", cd["id"]))
				for d: Dictionary in s["deck"].duplicate():
					var dd := card(str(d["id"]))
					if dd["type"] == "unit" and str(dd.get("group", dd["id"])) == g and d["uid"] != c["uid"]:
						s["deck"].erase(d)
						_play_unit(m, side, d, str(dd["row"]), false)
			"medic":
				var best: Dictionary = {}
				for d: Dictionary in s["discard"]:
					var dd := card(str(d["id"]))
					if dd["type"] == "unit" and not has_ability(dd, "elite") and not has_ability(dd, "medic") \
							and (best.is_empty() or int(dd["str"]) > int(card(str(best["id"]))["str"])):
						best = d
				if not best.is_empty():
					s["discard"].erase(best)
					_reset(best)
					s["hand"].append(best)
					_ev(m, {"k": "draw", "side": side, "uid": best["uid"]})
					_log(m, "  The medic brings %s back to %s's hand." % [cname(best), s["name"]])
			"assault":
				has_assault = true
				var t := _strongest(m, 1 - side, row, true)
				if not t.is_empty():
					_hit(m, 1 - side, t, n + (int(bz.get("assault_bonus", 1)) if blitz else 0), "assault")
	if blitz and not has_assault and not has_ability(cd, "elite"):
		var t := _strongest(m, 1 - side, row, true)
		if not t.is_empty():
			_hit(m, 1 - side, t, 1, "assault")


static func _play_tactic(m: Dictionary, side: int, c: Dictionary, move: Dictionary) -> void:
	var s: Dictionary = m["sides"][side]
	var o: Dictionary = m["sides"][1 - side]
	var cd := card(str(c["id"]))
	_log(m, "%s plays %s." % [s["name"], cd["name"]])
	_ev(m, {"k": "tactic", "side": side, "uid": c["uid"], "id": c["id"]})
	var to_discard := true
	match str(cd.get("effect", "")):
		"weather":
			m["weather"][str(cd.get("row_target", "arm"))] = true
		"clear":
			for r: String in ROWS:
				m["weather"][r] = false
		"air_superiority":
			m["weather"]["air"] = false
			s["boost"]["air"] = int(s["boost"]["air"]) + 2
		"doctrine":
			s["boost"]["arm"] = int(s["boost"]["arm"]) + (3 if is_blitz(m) else 2)
		"pincer":
			var best := 0
			for r: String in ROWS:
				for t: Dictionary in o["rows"][r]:
					if not _immune(t):
						best = maxi(best, eff(m, 1 - side, r, t))
			if best >= 8:
				for r: String in ROWS:
					for t: Dictionary in o["rows"][r].duplicate():
						if not _immune(t) and eff(m, 1 - side, r, t) == best:
							if t.get("shield", false):
								_hit(m, 1 - side, t, 1, "pincer")
							else:
								_log(m, "  The pincer closes on %s's %s." % [o["name"], cname(t)])
								_destroy(m, 1 - side, t)
			else:
				_log(m, "  …but nothing on the enemy side is big enough to encircle.")
		"codebreakers":
			o["reveal_all"] = true
			_ev(m, {"k": "reveal", "side": 1 - side})
			if not o["hand"].is_empty():
				var st_c: Dictionary = o["hand"][_ri(m, o["hand"].size())]
				o["hand"].erase(st_c)
				o["revealed"].erase(st_c["uid"])
				s["hand"].append(st_c)
				_ev(m, {"k": "steal", "side": side, "uid": st_c["uid"]})
				_log(m, "  The codebreakers read %s's orders and steal %s." % [o["name"], cname(st_c)])
			for i in int(cd.get("draw", 0)):
				_draw(m, side)
		"decoy":
			var tu := int(move.get("target", -1))
			var r := _row_of(m, side, tu)
			var row: Array = s["rows"][r]
			for i in row.size():
				if int(row[i]["uid"]) == tu:
					var back: Dictionary = row[i]
					_reset(back)
					s["hand"].append(back)
					c["decoy"] = true
					c["str"] = 0
					row[i] = c
					to_discard = false
					_ev(m, {"k": "play", "side": side, "uid": c["uid"], "row": r, "id": c["id"]})
					_log(m, "  Rubber tanks take the place of %s, which slips back to %s's hand." % [cname(back), s["name"]])
					break
		"barrage":
			var best_r := "inf"
			var bn := -1
			for r: String in ROWS:
				var n: int = o["rows"][r].size()
				if n > bn or (n == bn and row_score(m, 1 - side, r) > row_score(m, 1 - side, best_r)):
					bn = n
					best_r = r
			for t: Dictionary in o["rows"][best_r].duplicate():
				_hit(m, 1 - side, t, 2, "barrage")
		"draw":
			for i in 2:
				_draw(m, side)
	if to_discard:
		s["discard"].append(c)


static func _commander(m: Dictionary, side: int) -> void:
	var s: Dictionary = m["sides"][side]
	var o: Dictionary = m["sides"][1 - side]
	var cm := commander(str(s["commander"]))
	_log(m, "%s calls on %s." % [s["name"], cm.get("name", "the commander")])
	_ev(m, {"k": "commander", "side": side})
	match str(cm.get("effect", "")):
		"clear_draw":
			for r: String in ROWS:
				m["weather"][r] = false
			_draw(m, side)
		"boost_air":
			s["boost"]["air"] = int(s["boost"]["air"]) + 2
		"boost_arm":
			s["boost"]["arm"] = int(s["boost"]["arm"]) + 2
		"reveal_draw":
			o["reveal_all"] = true
			_ev(m, {"k": "reveal", "side": 1 - side})
			_draw(m, side)
		"summon_inf":
			var pool: Array = s["deck"].filter(func(x): return card(str(x["id"]))["type"] == "unit" and card(str(x["id"]))["row"] == "inf")
			pool.sort_custom(func(a, b): return int(a["str"]) > int(b["str"]))
			for i in mini(2, pool.size()):
				s["deck"].erase(pool[i])
				_play_unit(m, side, pool[i], "inf", false)
		"frost_enemy":
			m["weather"]["inf"] = true
			s["guard_inf"] = true


static func _autopass(m: Dictionary) -> void:
	var limit := int(data().get("blitz", {}).get("plays", 7))
	for i in 2:
		var s: Dictionary = m["sides"][i]
		if s["passed"]:
			continue
		if (s["hand"].is_empty() and s["cmd_used"]) or (is_blitz(m) and int(s["plays"]) >= limit):
			s["passed"] = true
			_ev(m, {"k": "pass", "side": i})
			_log(m, "%s %s and must pass." % [s["name"], "has no cards left" if s["hand"].is_empty() else "has spent every order"])


static func _after_move(m: Dictionary, side: int) -> void:
	_autopass(m)
	var a: Dictionary = m["sides"][0]
	var b: Dictionary = m["sides"][1]
	if a["passed"] and b["passed"]:
		if m.has("_sim"):
			return
		_end_round(m)
		return
	var other := 1 - side
	m["turn"] = other if not m["sides"][other]["passed"] else side


static func _end_round(m: Dictionary) -> void:
	var sa := score(m, 0)
	var sb := score(m, 1)
	var w := 0 if sa > sb else 1 if sb > sa else 2
	m["rounds"].append({"scores": [sa, sb], "winner": w})
	if w == 2:
		m["sides"][0]["wins"] = int(m["sides"][0]["wins"]) + 1
		m["sides"][1]["wins"] = int(m["sides"][1]["wins"]) + 1
		_log(m, "Round %d is a draw, %d to %d. Both sides take a gem." % [int(m["round"]), sa, sb])
	else:
		m["sides"][w]["wins"] = int(m["sides"][w]["wins"]) + 1
		_log(m, "%s wins round %d, %d to %d." % [m["sides"][w]["name"], int(m["round"]), maxi(sa, sb), mini(sa, sb)])
	_ev(m, {"k": "round_end", "winner": w, "scores": [sa, sb], "round": int(m["round"])})
	for i in 2:
		var s: Dictionary = m["sides"][i]
		for r: String in ROWS:
			for c: Dictionary in s["rows"][r]:
				_reset(c)
				s["discard"].append(c)
			s["rows"][r] = []
			s["boost"][r] = 0
		s["passed"] = false
		s["revealed"] = []
		s["reveal_all"] = false
		s["guard_inf"] = false
	for r: String in ROWS:
		m["weather"][r] = false
	var wa := int(m["sides"][0]["wins"])
	var wb := int(m["sides"][1]["wins"])
	if is_blitz(m) or wa >= 2 or wb >= 2 or int(m["round"]) >= int(m["max_rounds"]):
		m["over"] = true
		m["winner"] = 0 if wa > wb else 1 if wb > wa else 2
		_log(m, "The match is over: %s." % ("a draw" if m["winner"] == 2 else m["sides"][m["winner"]]["name"] + " wins"))
		_ev(m, {"k": "match_end", "winner": m["winner"]})
		return
	m["round"] = int(m["round"]) + 1
	for i in 2:
		_draw(m, i, false)
	m["turn"] = (1 - w) if w != 2 else (1 - int(m["first"]) if int(m["round"]) % 2 == 0 else int(m["first"]))
	_log(m, "Round %d begins; each side draws a card. %s leads." % [int(m["round"]), m["sides"][m["turn"]]["name"]])
	_autopass(m)
	if m["sides"][0]["passed"] and m["sides"][1]["passed"]:
		_end_round(m)
	elif m["sides"][m["turn"]]["passed"]:
		m["turn"] = 1 - int(m["turn"])


## The side gives up: the match ends at once in the opponent's favour.
static func concede(m: Dictionary, side: int) -> void:
	if m.get("over", false):
		return
	m["over"] = true
	m["winner"] = 1 - side
	_log(m, "%s concedes the match." % m["sides"][side]["name"])
	_ev(m, {"k": "match_end", "winner": m["winner"]})


## Every card uid in the match (deck, hand, rows, discard of both sides) — for conservation checks.
static func all_uids(m: Dictionary) -> Array:
	var out: Array = []
	for s: Dictionary in m["sides"]:
		for z in ["deck", "hand", "discard"]:
			for c: Dictionary in s[z]:
				out.append(int(c["uid"]))
		for r: String in ROWS:
			for c: Dictionary in s["rows"][r]:
				out.append(int(c["uid"]))
	return out


# =========================================================================== AI
## Picks a sensible move: plays strength when behind, passes when far ahead or out of cards,
## uses tactics, abilities and the commander, and sometimes bluffs (personality in m["ai"][side]).
static func ai_move(m: Dictionary, side: int) -> Dictionary:
	var moves := legal_moves(m, side)
	if moves.is_empty():
		return {}
	if moves.size() == 1:
		return moves[0]
	var prof: Dictionary = {}
	if m.get("ai", []) is Array and m["ai"].size() > side and m["ai"][side] is Dictionary:
		prof = m["ai"][side]
	var skill := float(prof.get("skill", 0.8))
	var bluff := float(prof.get("bluff", 0.15))
	var greed := float(prof.get("greed", 0.5))
	var s: Dictionary = m["sides"][side]
	var o: Dictionary = m["sides"][1 - side]
	var lead := score(m, side) - score(m, 1 - side)
	var hand_n: int = s["hand"].size()
	var opp_n: int = o["hand"].size()
	var blitz := is_blitz(m)
	var must_win := blitz or int(o["wins"]) >= 1
	var pass_mv := {"type": "pass"}
	# evaluate every non-pass move by simulating it
	var scored: Array = []
	for mv: Dictionary in moves:
		if mv["type"] == "pass":
			continue
		scored.append({"mv": mv, "v": _eval(m, side, mv, lead, hand_n, must_win, greed), "gain": 0})
	for e: Dictionary in scored:
		e["gain"] = int(e["v"]["swing"])
	if scored.is_empty():
		return pass_mv
	# --- the opponent has passed: win by the smallest margin possible, or fold
	if o["passed"]:
		if lead > 0:
			return pass_mv
		var winning := scored.filter(func(e): return lead + int(e["gain"]) > 0)
		if not winning.is_empty():
			winning.sort_custom(func(a, b): return float(a["v"]["cost"]) < float(b["v"]["cost"]))
			return winning[0]["mv"]
		var reach := lead
		for c: Dictionary in s["hand"]:
			reach += int(card(str(c["id"])).get("str", 0)) + 3
		if reach <= 0 and not must_win:
			return pass_mv
		# catching up would cost too many cards for a round we can afford to lose
		var needed := ceili(float(-lead + 1) / 6.5)
		if not must_win and (needed >= 3 or (needed == 2 and hand_n - 2 < opp_n)):
			return pass_mv
		scored.sort_custom(func(a, b): return int(a["gain"]) > int(b["gain"]))
		if int(scored[0]["gain"]) <= 0 and lead < 0 and not must_win:
			return pass_mv
		if lead == 0 and not must_win and int(scored[0]["gain"]) <= 0:
			return pass_mv
		return scored[0]["mv"]
	# --- both still playing
	if not blitz:
		var cushion := 9 + int(opp_n * 2.5 * (1.0 - greed))
		if lead >= cushion and hand_n <= opp_n + 2:
			return pass_mv
		if lead > 0 and opp_n == 0:
			return pass_mv
		# bluff: an early pass in the first round while holding card parity, to bait the opponent
		if int(m["round"]) == 1 and lead >= 0 and int(m["turns"]) >= 4 and hand_n >= opp_n and _rf(m) < bluff * 0.5:
			return pass_mv
		# concede a round that is slipping away when a loss is affordable and cards are worth more
		if not must_win and lead <= -14 and hand_n <= opp_n + 1 and _rf(m) < 0.8:
			return pass_mv
		if not must_win and lead <= -8 and hand_n <= opp_n and int(s["plays"]) >= 4 and _rf(m) < 0.5 + 0.4 * skill:
			return pass_mv
		# do not pour the whole hand into the first round
		if int(m["round"]) == 1 and int(s["wins"]) == 0 and hand_n <= 4 and lead > 0 and hand_n <= opp_n:
			return pass_mv
	scored.sort_custom(func(a, b): return float(a["v"]["value"]) > float(b["v"]["value"]))
	# bluff: sometimes lead with a small card first in round one
	if int(m["round"]) == 1 and not blitz and int(s["plays"]) == 0 and _rf(m) < bluff:
		var small := scored.filter(func(e): return e["mv"]["type"] == "play" and int(e["gain"]) > 0)
		if not small.is_empty():
			small.sort_custom(func(a, b): return int(a["gain"]) < int(b["gain"]))
			return small[0]["mv"]
	if float(scored[0]["v"]["value"]) < -3.0 and lead > 0 and not blitz:
		return pass_mv
	var pick := 0
	if _rf(m) > skill and scored.size() > 1:
		pick = _ri(m, mini(3, scored.size()), "ai_rs")
	return scored[pick]["mv"]


static func _eval(m: Dictionary, side: int, mv: Dictionary, lead: int, hand_n: int, must_win: bool, greed: float) -> Dictionary:
	var sim: Dictionary = m.duplicate(true)
	sim["_sim"] = true
	sim["events"] = []
	apply(sim, side, mv)
	var new_lead := score(sim, side) - score(sim, 1 - side)
	var swing := new_lead - lead
	var hand_after: int = sim["sides"][side]["hand"].size()
	var card_adv := hand_after - (hand_n - (1 if mv["type"] == "play" else 0))
	var cost := 0.0
	if mv["type"] == "play":
		var c := _hand_card(m["sides"][side], int(mv["uid"]))
		var cd := card(str(c.get("id", "")))
		cost = float(cd.get("str", 0)) if cd.get("type", "") == "unit" else 4.0
		if cd.get("effect", "") == "decoy":
			var tgt: Dictionary = {}
			for r: String in ROWS:
				for u: Dictionary in m["sides"][side]["rows"][r]:
					if int(u["uid"]) == int(mv.get("target", -1)):
						tgt = u
			var td := card(str(tgt.get("id", "")))
			# re-using a spotter / supply / medic / damaged unit is the point of the decoy
			var reuse := 0.0
			for k in ["supply", "medic", "spotter", "artillery", "barrage", "reinforce"]:
				if has_ability(td, k):
					reuse += 3.0
			if int(tgt.get("str", 0)) < int(td.get("str", 0)):
				reuse += 2.0
			card_adv += 0
			swing += int(reuse)
		if cd.get("type", "") == "unit" and has_ability(cd, "spotter"):
			swing += 1
	else:
		cost = 6.0   # commander: keep it for a moment that matters
	var conserve := (0.0 if must_win else 0.35 + 0.25 * (1.0 - greed)) if not is_blitz(m) else 0.0
	var value := float(swing) + 3.5 * card_adv - conserve * cost
	if mv["type"] == "commander" and swing < 4 and not must_win:
		value -= 6.0
	return {"swing": swing, "value": value, "cost": cost + (0.0 if card_adv <= 0 else -2.0 * card_adv)}


## Plays a whole match AI against AI (tests, balancing). Returns the finished match.
static func simulate(deck_a: Dictionary, deck_b: Dictionary, mode := "standard", seed := 1, opts: Dictionary = {}) -> Dictionary:
	var m := new_match(deck_a, deck_b, mode, seed, opts)
	var guard := 0
	while not m["over"] and guard < 400:
		guard += 1
		var side := int(m["turn"])
		var mv := ai_move(m, side)
		if mv.is_empty() or not apply(m, side, mv):
			apply(m, side, {"type": "pass"})
	m["guard"] = guard
	return m


# =========================================================================== rewards
## Applies the end-of-match reward for side 0 (the player) exactly once and records the result.
## Returns {cards: [ids], gold: n, result: "win"|"loss"|"draw", unlocked: [opp ids]}.
static func finish_reward(m: Dictionary) -> Dictionary:
	if not m.get("over", false):
		return {}
	if m.has("reward"):
		return m["reward"]
	var opp: String = m.get("opp", "")
	var o := opponent(opp)
	var tier := clampi(int(o.get("tier", 1)), 1, 3)
	var rw: Dictionary = data().get("rewards", {})
	var w := int(m["winner"])
	var res := "win" if w == 0 else "loss" if w == 1 else "draw"
	var out := {"cards": [], "gold": 0, "result": res, "unlocked": []}
	if m.get("tutorial", false):
		# v1.7: the teaching match is replayable, but Barnaby's welcome purse is paid once (never cards)
		out["gold"] = 10 if res == "win" and not bool(st().get("tutorial_rewarded", false)) else 0
		if res == "win":
			st()["tutorial_rewarded"] = true
			st()["tutorial_won"] = true
	elif res == "win":
		out["gold"] = int(rw.get("gold_win", [0, 20, 35, 55])[tier])
		var n := int(rw.get("cards_win", [0, 1, 1, 2])[tier])
		if is_blitz(m):
			out["gold"] = int(out["gold"] * 0.75)
		for i in n:
			var id := random_card(_weighted_rarity(rw.get("tier_odds", {}).get(str(tier), {})))
			if id != "" and grant_card(id, "win:" + opp):
				out["cards"].append(id)
	elif res == "draw":
		out["gold"] = int(int(rw.get("gold_win", [0, 20, 35, 55])[tier]) / 2)
	else:
		out["gold"] = int(rw.get("gold_loss", 8))
	if int(out["gold"]) > 0:
		Game.add_gold(int(out["gold"]), "ironfront", "Ironfront at Barnaby's table", "ironfront")
	if opp != "" and not m.get("tutorial", false):
		var rec := record(opp)
		rec[{"win": "w", "loss": "l", "draw": "d"}[res]] = int(rec.get({"win": "w", "loss": "l", "draw": "d"}[res], 0)) + 1
		st()["matches"] = int(st().get("matches", 0)) + 1
		out["unlocked"] = _refresh_unlocks()
		if res == "win" and int(rec["w"]) == 1:
			Chronicle.add("social", "Brannoc beat %s at Ironfront in Barnaby's basement." % o.get("name", opp), {"npc": opp})
	if m.get("tutorial", false):
		st()["tutorial_done"] = true
		_close_invite()
	m["reward"] = out
	return out


# =========================================================================== flavour
const LORE := [
	"\"Ironfront? Only the finest game ever played on felt! Three fronts — Infantry, Armour, Air. Best of three rounds. The trick is to win a round with as few cards as you can. Restraint, my friend. Restraint!\"",
	"\"The machines? Oh, they're real — or real somewhere. A tinker's widow left me crates of the cards: steel beetles that breathe thunder, iron birds with spinning noses, wagons of organ pipes that sing fire. I've painted miniatures of every one.\"",
	"\"The Tiger I is a beetle the size of a barn. Shells bounce off it like hail. But it's slow, and Mud Season turns it into a very expensive bathtub.\"",
	"\"Never underestimate the codebreakers. A dozen clever folk in a country house, reading the other fellow's letters. Steals a card right out of your hand. Delicious.\"",
	"\"Operation Fortitude! An entire army made of painted canvas and rubber, inflated with bicycle pumps. You put a decoy down and take your real unit back to play again. The other side never knows.\"",
	"\"Blitzkrieg is the quick game: one round, eight cards, everyone hits as they land. Good for when the forge is cooling and you've only an hour.\"",
	"\"Some cards are found only on the road — merchants trade them, adventurers dig them out of ruins. I'd give my second-best helmet for a Tiger II.\"",
]


static func barnaby_lore() -> String:
	var n := int(st().get("lore", 0))
	st()["lore"] = n + 1
	return LORE[n % LORE.size()]



# ------------------------------------------------------------------ the invitation (a new game)
## A new game: Barnaby slips an invitation under the smithy door — come to the basement, learn the rules and
## play an introductory match. A talk marker on the minimap points to him until the match is played.
static func invite_new() -> void:
	st()["invite"] = "pending"
	TalkMarkers.flag("barnaby", "invites you to an introductory game of Ironfront")
	Game.journal("A note under the door, in a careful hand: \"Master Ironhand — would you do me the honour of a game of IRONFRONT? Basement of my house, north lane, any evening. Helmets provided. — B. Quill\"")
	Chronicle.add("social", "Barnaby Quill invited the new smith to an introductory game of Ironfront.", {"npc": "barnaby"})
	var tree := Game.get_tree()
	if tree:
		tree.create_timer(6.0).timeout.connect(func():
			if invite_pending():
				Events.toast.emit("A note under the door: Barnaby Quill invites you to a game of Ironfront (his house, north lane).", "info"))


static func invite_pending() -> bool:
	return str(st().get("invite", "")) == "pending"


## Barnaby's introduction when you answer the invitation.
static func intro_text() -> String:
	return "\"You came! Splendid. Helmet — here, regulations. Now: Ironfront. Picture machines no wizard ever dreamed of — " + \
		"steel beetles that breathe thunder, iron birds that dive and shriek, wagons that fire a hundred arrows of flame at once. " + \
		"The Sherman, the Tiger, the Spitfire! Three fronts — Infantry, Armour, Air. You play a card or you pass; once you pass, " + \
		"you're out until the round ends. Best of three rounds. Shall I walk you through a first match? I'll coach — you'll have it in no time.\""


static func _close_invite() -> void:
	if invite_pending():
		st()["invite"] = "done"
		TalkMarkers.clear("barnaby")
		Chronicle.add("social", "Brannoc played his first game of Ironfront in Barnaby's basement.", {"npc": "barnaby"}, true)
		Social.change("barnaby", 8.0, 10.0, "ironfront_intro", "The smith accepted my invitation and played Ironfront with me!")


# =========================================================================== v1.7 (#70): Barnaby's introduction & trade
## Canonical v1.7 §11. The loaner deck is Barnaby's (lent, never sold back); Barnaby buys the smith's spare cards at a
## modest price and sells, besides his daily shelf, the cards adventurers found on the road and sold him; a party now and
## then carries a painted card home from an expedition (a hireling's find is the smith's haul; an adventurer's is theirs
## until they sell it to Barnaby). The Field Manual explains every card, a few lessons at a time; the teaching match is
## a fixed, winnable deal with Barnaby's suggestions.
const SELL_PRICE := {"common": 6, "uncommon": 14, "rare": 36, "special": 110}
const SHELF_SPECIAL_PRICE := 240
const SHELF_MAX := 8
const FOUND_CHANCE := 0.04       # a returning party carries a painted card home
const TEACHING_SEED := 1918      # the teaching match's fixed deal (a real, winnable game)


## A fixed chance for `key` in [0, 1) — the card-find rolls use it, so they never draw from the game's random numbers.
static func roll(key: String) -> float:
	return float(hash(key + "|ironfront") & 0xffffff) / 16777216.0


static func lent(id: String) -> int:
	return int(st()["lent"].get(id, 0))


## Copies the smith may sell: owned, less the lent loaner copies and what the active deck uses.
static func spare(id: String) -> int:
	var in_deck := int(active_deck().get("cards", {}).get(id, 0))
	return maxi(0, owned(id) - maxi(lent(id), in_deck))


static func sell_price(id: String) -> int:
	return int(SELL_PRICE.get(str(card(id).get("rarity", "common")), 6))


## Sells one spare copy to Barnaby; returns the gold paid (0 = refused).
static func sell_card(id: String) -> int:
	if card(id).is_empty() or spare(id) <= 0:
		return 0
	var col: Dictionary = st()["collection"]
	col[id] = int(col[id]) - 1
	if int(col[id]) <= 0:
		col.erase(id)
	var price := sell_price(id)
	Game.add_gold(price, "ironfront", "Sold an Ironfront card to Barnaby: %s" % card(id)["name"], "barnaby")
	st()["sold"] = int(st().get("sold", 0)) + 1
	return price


## A painted card found on an expedition. `finder` is an adventurer (they keep it, to sell to Barnaby) or, with
## `smiths` true, the smith's own hireling (it comes home in the smith's haul). Returns the card id ("" = none).
static func card_found(finder: Dictionary, smiths := false, rarity := "", key := "") -> String:
	# its own dice (seeded by `key`, e.g. the expedition): a find never shifts the game's other random draws
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key) if key != "" else randi()
	var r := rarity
	if r == "":
		var x := rng.randf()
		r = "common" if x < 0.5 else "uncommon" if x < 0.8 else "rare" if x < 0.95 else "special"
	var pool := all_cards().filter(func(c): return c["rarity"] == r)
	if pool.is_empty():
		return ""
	var id := str(pool[rng.randi() % pool.size()]["id"])
	if smiths:
		grant_card(id, "hireling:" + str(finder.get("id", "")))
	else:
		if not finder.has("ironfront_cards"):
			finder["ironfront_cards"] = []
		(finder["ironfront_cards"] as Array).append(id)
	return id


## Daily: adventurers in Brindlewick who carry cards sell them to Barnaby (paid from his till into their purse); they
## join his "found on the road" shelf. The shelf holds SHELF_MAX — the oldest goes to a collector.
static func on_day() -> void:
	if not Game.state.has("ironfront"):
		return
	var shelf: Array = st()["shelf"]
	for a in Adv.all().values():
		var cards: Array = a.get("ironfront_cards", [])
		if cards.is_empty() or str(a.get("status", "")) != "in_town":
			continue
		for id in cards:
			var price := sell_price(str(id))
			a["gold"] = int(a.get("gold", 0)) + price
			shelf.append({"id": str(id), "from": str(a["id"]), "name": str(a.get("name", "")), "day": Game.day()})
			Game.journal("%s sold Barnaby a painted Ironfront card found on the road: %s." % [a.get("name", ""), card(str(id)).get("name", id)])
		a["ironfront_cards"] = []
	while shelf.size() > SHELF_MAX:
		shelf.pop_front()


static func shelf_price(id: String) -> int:
	return SHELF_SPECIAL_PRICE if bool(card(id).get("special", false)) else single_price(id)


static func found_shelf() -> Array:
	return st()["shelf"]


static func buy_found(index: int) -> bool:
	var shelf: Array = st()["shelf"]
	if index < 0 or index >= shelf.size():
		return false
	var e: Dictionary = shelf[index]
	var price := shelf_price(str(e["id"]))
	if not Game.can_afford(price):
		return false
	Game.add_gold(-price, "ironfront", "Ironfront card from Barnaby's found shelf: %s" % card(str(e["id"])).get("name", ""), "barnaby")
	grant_card(str(e["id"]), "shelf:" + str(e.get("from", "")))
	shelf.remove_at(index)
	return true


# ---------------------------------------------------------------- the Field Manual: every card, a few lessons at a time
## Lessons in order: the loaner deck, the other Allies, the Axis, the Soviets, the tactics, the rare finds. Every
## defined card is in exactly one lesson. Lesson 1 is open from the start, lesson 2 after the teaching match, then one
## more each new day the smith sits at Barnaby's table (Ironfront.visit_table).
static func lessons() -> Array:
	var starter: Dictionary = data().get("starter_deck", {}).get("cards", {})
	var out := [
		{"title": "Lesson 1 — Your loaner deck", "intro": "\"These are the lads you'll command first. Learn them well.\"", "cards": []},
		{"title": "Lesson 2 — The rest of the Allies", "intro": "\"Tea, tanks and nerve. More of them, and better.\"", "cards": []},
		{"title": "Lesson 3 — The Axis", "intro": "\"Few, heavy and terrible. Know them before they know you.\"", "cards": []},
		{"title": "Lesson 4 — The Soviets", "intro": "\"Endless companies and very hard frost.\"", "cards": []},
		{"title": "Lesson 5 — Tactics", "intro": "\"Weather, deception and doctrine — any deck may carry them.\"", "cards": []},
		{"title": "Lesson 6 — Rare finds", "intro": "\"Found only on the road. I'd give my second-best helmet for one.\"", "cards": []},
	]
	for c: Dictionary in all_cards():
		var id := str(c["id"])
		var i := 0
		if c.get("special", false):
			i = 5
		elif starter.has(id):
			i = 0
		elif str(c.get("type", "")) == "tactic" or str(c.get("faction", "")) == "neutral":
			i = 4
		else:
			i = {"allies": 1, "axis": 2, "soviet": 3}.get(str(c.get("faction", "")), 4)
		(out[i]["cards"] as Array).append(id)
	return out


static func lessons_open() -> int:
	var n := int(st().get("manual_open", 1))
	if bool(st().get("tutorial_done", false)):
		n = maxi(n, 2)
	return clampi(n, 1, lessons().size())


## The smith sits at Barnaby's table today: after the teaching match, one more lesson each new day.
static func visit_table() -> void:
	var s := st()
	if not bool(s.get("tutorial_done", false)):
		return
	if int(s.get("manual_day", -1)) == Game.day():
		return
	s["manual_day"] = Game.day()
	var was := lessons_open()
	if int(s.get("manual_visits", 0)) > 0:
		s["manual_open"] = mini(lessons().size(), was + 1)
	else:
		s["manual_open"] = was
	s["manual_visits"] = int(s.get("manual_visits", 0)) + 1


## Barnaby's explanation of one card: its front, strength, abilities in plain words, and whether the smith has it.
static func explain(id: String) -> String:
	var c := card(id)
	if c.is_empty():
		return ""
	var head := "[b]%s[/b] — %s %s" % [c["name"], RARITY_NAMES.get(str(c.get("rarity", "")), ""),
		"tactic" if str(c.get("type", "")) == "tactic" else "%s, strength %d" % [ROW_NAMES.get(str(c.get("row", "")), ""), int(c.get("str", 0))]]
	var ab := ability_text(c)
	var own := owned(id)
	var where := ("you hold %d%s" % [own, " (lent)" if lent(id) > 0 else ""]) if own > 0 else ("found only on the road" if c.get("special", false) else "on my shelf some days, or in a pack")
	return head + ("\n" + ab if ab != "" else "\nNo special ability — honest strength.") + "\n[i]%s · %s[/i]" % [str(c.get("flavor", "")), where]


# ---------------------------------------------------------------- the teaching match
## Barnaby's proud introduction, a page at a time (the in-character opening before the teaching match).
const INTRO_PAGES := [
	"\"Welcome, welcome — mind the step, mind the helmet! You are standing in the [b]war-room[/b] of Ironfront, the finest game ever played on felt, and I, Barnaby Quill, am its humble keeper.\"",
	"\"Picture machines no wizard ever dreamed of: steel beetles that breathe thunder, iron birds that dive and shriek. Each card fights on one front — [b]Infantry[/b], [b]Armour[/b] or [b]Air[/b] — and adds its strength there.\"",
	"\"You play one card, or you [b]pass[/b]. Once you pass you're out until the round ends. The bigger army wins the round; best of three. And cards don't come back — so win cheaply, lose cheaply. [i]Restraint![/i]\"",
	"\"I'll lend you my own loaner deck — good honest lads, a commando or two. Sit, and I'll whisper the right move each turn and tell you why. Win this one, and the war-room is yours.\"",
]


## The best move for `side` and Barnaby's reason, in plain words (the coach's suggestion).
static func suggest(m: Dictionary, side: int) -> Dictionary:
	var keep: Variant = m["ai"][side] if m.get("ai", []) is Array and (m["ai"] as Array).size() > side else {}
	m["ai"][side] = {"skill": 1.0, "bluff": 0.0, "greed": 0.5}
	var rs := int(m.get("ai_rs", 1))
	var mv := ai_move(m, side)
	m["ai_rs"] = rs   # a suggestion never changes the game's own dice
	m["ai"][side] = keep
	if mv.is_empty():
		return {}
	var s: Dictionary = m["sides"][side]
	var o: Dictionary = m["sides"][1 - side]
	var lead := score(m, side) - score(m, 1 - side)
	var why := ""
	match str(mv["type"]):
		"pass":
			if bool(o["passed"]) and lead > 0:
				why = "Barnaby has passed and you lead by %d — pass now and keep every card in your hand for the next round." % lead
			elif lead > 0:
				why = "You're ahead by %d. Pass, and make me spend my cards to catch up — or give the round up cheaply." % lead
			else:
				why = "This round isn't worth more cards. Pass, let me have it, and keep your strength for the next."
		"commander":
			why = "Your Commander's order — once per match. Now is the moment: %s" % str(commander(str(s["commander"])).get("text", "it turns the round."))
		"play":
			var hc := _hand_card(s, int(mv["uid"]))
			var cc := card(str(hc.get("id", "")))
			var abl := ability_text(cc)
			why = "Play [b]%s[/b]%s. %s" % [cc.get("name", "it"), (" on " + ROW_NAMES.get(str(cc.get("row", "")), "") if str(cc.get("type", "")) != "tactic" else ""),
				abl if abl != "" else "Its %d strength is what this front needs." % int(cc.get("str", 0))]
			if bool(o["passed"]):
				why += " I've passed — you only need to get ahead, then stop."
	return {"move": mv, "why": why}

