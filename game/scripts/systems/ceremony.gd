## Ceremony — a public honour in the village square the day after an Epic deed.
## EN: Ceremony.schedule() (called by Recognition.grant_epic, or by any system for another major public
##     achievement) books a gathering for the next day at noon: the honoured adventurer stands at the
##     podium ("square_podium", falling back to the square spots) and villagers gather around from 11:00
##     to 14:00 (VillageWorld.spot_for asks spot_for() first — a two-line hook). The smith is invited by a
##     toast and a minimap talk marker on the adventurer (TalkMarkers.flag). Walking into the square while
##     it is on (tick(), called from the world each frame, throttled) or using the podium board holds the
##     ceremony: a short scene (HallOfFamePanel in ceremony mode), applause, renown and reputation, and a
##     plaque on the Hall of Fame. Missing it lets the village hold it without the smith.
##     State: Game.state["ceremony"] (lazy): {day, hour, adv, uid, deed, status: scheduled|held|missed, crowd}.
## DA: En ceremoni på torvet dagen efter en episk bedrift: eventyreren ved podiet, landsbyen samles,
##     smeden inviteres (skål + markør). Deltagelse giver applaus, omdømme og en plade i Æreshallen.
class_name Ceremony
extends RefCounted

const START_HOUR := 11      # people gather
const NOON := 12
const END_HOUR := 14        # it is over by two
const CROWD := ["martha", "tobin", "jory", "eda", "oswin", "barnaby", "aldric", "hilde"]
const ATTEND_RADIUS := 520.0
const RENOWN := 10          # the smith's public renown (Game.state["world"]["smith_renown"])
const REP := 6.0

static var _t := 0.0


static func state() -> Dictionary:
	if not Game.state.has("ceremony"):
		Game.state["ceremony"] = {}
	return Game.state["ceremony"]


static func scheduled() -> bool:
	return str(state().get("status", "")) == "scheduled"


## Books a ceremony for tomorrow at noon (one at a time: a second honour joins the one already booked).
static func schedule(adv_id: String, uid := -1, deed := "", reason := "epic") -> Dictionary:
	var c := state()
	if scheduled() and int(c.get("day", 0)) >= Game.day():
		var more: Array = c.get("also", [])
		more.append({"adv": adv_id, "uid": uid, "deed": deed})
		c["also"] = more
		return c
	var crowd := []
	for v in CROWD:
		if not DB.character(v).is_empty() and Hire.get_h(v).is_empty():
			crowd.append(v)
	c.clear()
	c.merge({"day": Game.day() + 1, "hour": NOON, "adv": adv_id, "uid": uid, "deed": deed, "reason": reason,
		"status": "scheduled", "crowd": crowd, "booked": Game.day()})
	if adv_id != "":
		TalkMarkers.flag(adv_id, "Invites you to a ceremony in the square tomorrow at noon")
	var who := Talk.npc_name(adv_id) if adv_id != "" else "The village"
	Events.toast.emit("A toast to the smith! %s invites you to a ceremony in the village square tomorrow at noon." % who, "good")
	Game.journal("%s raised a toast to me. There will be a ceremony in the square tomorrow at noon (day %d)." % [who, Game.day() + 1])
	return c


## Are people gathered in the square right now?
static func gathering() -> bool:
	var c := state()
	if c.is_empty() or int(c.get("day", -1)) != Game.day():
		return false
	var h := Game.hour()
	return str(c.get("status", "")) in ["scheduled", "held"] and h >= START_HOUR and h < END_HOUR


## Can the smith attend right now?
static func can_attend() -> bool:
	return scheduled() and gathering()


## Lazy bookkeeping: a ceremony whose hour has passed without the smith is held without him.
static func update() -> void:
	var c := state()
	if not scheduled():
		return
	var late: bool = Game.day() > int(c["day"]) or (Game.day() == int(c["day"]) and Game.hour() >= END_HOUR)
	if not late:
		return
	c["status"] = "missed"
	TalkMarkers.clear(str(c.get("adv", "")))
	Shop.rep_change(1.0)
	if str(c.get("adv", "")) != "":
		Social.change(str(c["adv"]), -2.0, 1.0, "", "", false)
	Chronicle.add("social", "The square honoured %s's deed at noon — the smith was not there to hear it." % Talk.npc_name(str(c.get("adv", ""))), {"adv": str(c.get("adv", ""))})


## World schedule override (VillageWorld.spot_for): "" when the ceremony does not concern this NPC now.
static func spot_for(id: String, spots: Dictionary) -> String:
	if Game.state.is_empty() or not Game.state.has("ceremony") or not gathering():
		return ""
	var c := state()
	var podium := "square_podium" if spots.has("square_podium") else "square_0"
	if id == str(c.get("adv", "")):
		var a := Adv.get_a(id)
		if not a.is_empty() and str(a.get("status", "")) in ["away", "dead", "missing"]:
			return ""
		return podium
	var crowd: Array = c.get("crowd", [])
	var i := crowd.find(id)
	if i < 0:
		return ""
	var near := ["square_1", "square_2", "square_3", "square_4", "square_5", "well", "notice", "square_0"].filter(func(s): return s != podium and spots.has(s))
	if near.is_empty():
		return ""
	return str(near[i % near.size()])


## Called by the world every frame (throttled): the smith walking into the gathered square holds it.
static func tick(player_pos: Vector2, spots: Dictionary, delta: float) -> void:
	_t += delta
	if _t < 0.5:
		return
	_t = 0.0
	if Game.state.is_empty() or not Game.state.has("ceremony"):
		return
	update()
	if not can_attend():
		return
	var at: Vector2 = spots.get("square_podium", spots.get("square_0", Vector2.INF))
	if at == Vector2.INF or player_pos.distance_to(at) > ATTEND_RADIUS:
		return
	attend()
	Events.open_panel.emit("hall_of_fame", {"id": "square", "ceremony": true})


## The short scene: [[speaker id or "", line], …] for the panel.
static func scene_lines(c := {}) -> Array:
	if c.is_empty():
		c = state()
	var adv := str(c.get("adv", ""))
	var who := Talk.npc_name(adv) if adv != "" else "a hero of the village"
	var it := Game.find_uid_anywhere(int(c.get("uid", -1)))
	var piece: String = str(it.get("name", "the smith's work"))
	var deed := str(c.get("deed", "did something worth a song"))
	var crowd: Array = c.get("crowd", [])
	var crier: String = crowd[0] if not crowd.is_empty() else ""
	return [
		[crier, "\"Gather round! Brindlewick has a deed to celebrate.\""],
		[adv, "\"They say I %s. True enough — but I didn't do it alone.\"" % deed],
		[adv, "\"This — %s — was made here, by Brannoc Ironhand. Raise your cups to the smith!\"" % piece],
		["", "[i]The square erupts in applause. Somebody starts the old forging song.[/i]"],
		[crowd[1] if crowd.size() > 1 else crier, "\"To the Ironhand forge!\""],
	]


## The smith attends: applause, renown and reputation, the adventurer's and the crowd's regard, a plaque.
static func attend() -> Dictionary:
	var c := state()
	if not scheduled():
		return {}
	c["status"] = "held"
	c["attended"] = true
	c["held_day"] = Game.day()
	var adv := str(c.get("adv", ""))
	TalkMarkers.clear(adv)
	var w: Dictionary = Game.state["world"]
	w["smith_renown"] = int(w.get("smith_renown", 0)) + RENOWN
	Shop.rep_change(REP, "the village publicly honoured the smith's work.")
	if adv != "":
		Social.change(adv, 8.0, 5.0, "ceremony_%d" % Game.day(), "Brannoc stood beside me in the square when they honoured my deed.")
	for v in c.get("crowd", []):
		Social.change(str(v), 2.0, 1.0, "", "", false)
	Audio.play("sfx/applause")
	var who := Talk.npc_name(adv) if adv != "" else "the village"
	Recognition.record("ceremony", "Honoured in the square", "On day %d the village gathered at noon; %s credited the smith before everyone." % [Game.day(), who],
		{"adv": adv, "uid": int(c.get("uid", -1))}, "ceremony_%d" % int(c.get("booked", Game.day())))
	Chronicle.add("social", "In the square at noon, %s raised a cup to Brannoc Ironhand, whose work made the deed possible." % who, {"adv": adv}, true)
	Events.toast.emit("The square applauds the smith! (+%d renown, reputation up)" % RENOWN, "legendary")
	return c


static func smith_renown() -> int:
	return int(Game.state.get("world", {}).get("smith_renown", 0))
