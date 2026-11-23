## Visitors — credible renowned visitors with reasons to come (R8 "World Recognition"; WLD-016, WLD-015, QST-018).
## EN: The persistent people of the region who might come to the forge in person are the patrons already in the world
##     (data/contracts.json): the Highmarsh wool merchant, the Merchants' Guild, the Highmarsh Watch and the Warden of
##     the Western Marches. Each listens to one audience (traders or nobility). A visitor comes only for a reason the
##     records show: news of the smith's work has reached the region by a real channel (Reputation.carry — travel, a
##     ship, a letter), what that audience there has heard is good enough (VISIT_WORD), the smith's standing is within
##     one tier of theirs, and they have not come in the last REVISIT days. The visit is recorded with its reason and
##     channel; when one of their orders fits the forge, they bring the letter in person. Renown cannot be bought:
##     gold appears nowhere in these rules — only deeds that spread.
##     While the steward runs the forge, a visitor who finds the smith away leaves a sealed letter (political and
##     patron commitments are the smith's to make).
##     State: Game.state["visitors"] = {last: {patron: day}, log: [visit]} (created on the first visit).
## DA: Troværdige besøgende: kun når nyheden om smedens værk har nået dem ad en virkelig kanal.
class_name Visitors
extends RefCounted

const CAST := {"odo_varrick": "traders", "merchants_guild": "traders", "highmarsh_watch": "nobility", "warden_aldwin": "nobility"}
const VISIT_WORD := 3.0
const REVISIT := 30
const GAP := 5   # days between any two visits


static func st() -> Dictionary:
	var v: Variant = Game.state.get("visitors", {})
	return v if v is Dictionary else {}


static func log_list() -> Array:
	return st().get("log", [])


## Why this patron would come now ("" when they would not): the news they heard and the channel that carried it.
static func reason(pid: String) -> Dictionary:
	var aud := str(CAST.get(pid, ""))
	if aud == "":
		return {}
	if Reputation.word(aud, "region") < VISIT_WORD:
		return {}
	var n := Reputation.latest_heard("region", aud)
	if n.is_empty():
		return {}
	var last := int(st().get("last", {}).get(pid, -999))
	if Game.day() - last < REVISIT:
		return {}
	if int(n.get("heard", {}).get("region", {}).get(aud, -1)) < last:
		return {}   # nothing new has reached them since they came
	var tier := int(Contracts.patron(pid).get("tier", 1))
	if tier > int(Contracts.standing()["tier"]) + 1:
		return {}
	var whys: Array = n.get("why", [])
	return {"news": str(n["id"]), "why": str(whys[0]) if not whys.is_empty() else "of the forge's work", "via": str(n.get("via", {}).get("region", {}).get(aud, "travel")),
		"audience": aud}


## The daily round: at most one visitor, the one with the freshest reason.
static func on_day(_day: int) -> void:
	if Game.state.is_empty() or not Game.state.get("reputation") is Dictionary:
		return
	var s := st()
	if Game.day() - int(s.get("last_any", -999)) < GAP:
		return
	for pid in CAST:
		var r := reason(str(pid))
		if not r.is_empty():
			visit(str(pid), r)
			return


static func visit(pid: String, r: Dictionary) -> Dictionary:
	if not Game.state.get("visitors") is Dictionary:
		Game.state["visitors"] = {"last": {}, "log": [], "last_any": -999}
	var s: Dictionary = Game.state["visitors"]
	var name := Contracts.patron_name(pid)
	var title := str(Contracts.patron(pid).get("title", ""))
	var via_word: String = {"travel": "travellers on the road", "ship": "a ship's crew", "letter": "a letter"}.get(str(r["via"]), str(r["via"]))
	var text := "%s, %s, came to Brindlewick in person: in the region they had heard (from %s) that %s." % [name, title, via_word, str(r["why"]).trim_suffix(".").to_lower()]
	var ev := Lore.record("visit", text, {"actors": ["patron_" + pid], "roles": {"patron_" + pid: "visitor"}, "place": "brindlewick", "importance": 2,
		"chronicle": true, "data": {"news": str(r["news"]), "via": str(r["via"]), "audience": str(r["audience"])}})
	s["last"][pid] = Game.day()
	s["last_any"] = Game.day()
	var rec := {"day": Game.day(), "patron": pid, "name": name, "why": str(r["why"]), "via": str(r["via"]), "event": ev, "offer": ""}
	(s["log"] as Array).append(rec)
	while (s["log"] as Array).size() > 40:
		(s["log"] as Array).pop_front()
	# an order of theirs that fits the forge: they bring the letter themselves
	for tpl in Contracts.data().get("templates", []):
		if str(tpl.get("patron", "")) == pid and Contracts._offerable(tpl):
			Lore.push_cause(ev)
			var c := Contracts.make_offer(str(tpl["id"]), "They came in person: in the region they had heard that %s." % str(r["why"]).trim_suffix(".").to_lower())
			Lore.pop_cause()
			rec["offer"] = str(c.get("id", ""))
			break
	if Steward.smith_away():
		Steward.defer("political", "%s came while you were away and left a sealed letter: %s" % [name, text], {"type": "visitor", "id": pid,
			"from": name, "key": "visit:%s:%d" % [pid, Game.day()]}, true, {"route": "contracts", "args": {"id": str(rec["offer"])}} if str(rec["offer"]) != "" else {})
	else:
		Events.toast.emit(text, "good")
	return rec
