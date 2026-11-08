## Memorial — what remains when a hireling does not come home: the funeral, the grave, the friendly
## ghost that sometimes visits the workshop, the wildflowers it leaves and the vase that keeps them.
## EN: All state lives in Game.state["memorial"] (created lazily, so old saves load):
##     graves  — [{id, name, look, race, hired_day, died_day, dest, dest_name, expeditions, achievements,
##                history, plot, funeral_day, funeral_done, attended}]
##     visit   — {} or {id, day, met} — a ghost visiting the workshop this evening
##     seen    — {hireling id: times met}
##     flowers — [{id, name, day}] wildflowers lying outside the smithy door (pickups)
##     vase    — {} or {id, name, day} — whose flowers stand in the vase in the quarters
## DA: Begravelse, gravsten, venlige genfærd, markblomster ved døren og vasen i kammeret.
class_name Memorial
extends RefCounted

const FUNERAL_HOUR := 10
const GHOST_AFTER_DAYS := 14       # a few weeks after the funeral
const GHOST_CHANCE := 0.12         # per quiet evening, for the whole graveyard
const GHOST_GAP_DAYS := 5
const GHOST_FROM_HOUR := 19
const PLOTS := 8
const VILLAGE_MOURNERS := ["martha", "tobin", "eda", "jory", "aldric", "hilde", "barnaby", "herbalist", "wenna"]

## When a test wants a visit tonight it sets this (cleared after use).
static var force_ghost := false


static func st() -> Dictionary:
	if not Game.state.has("memorial"):
		Game.state["memorial"] = {}
	var m: Dictionary = Game.state["memorial"]
	for k in ["graves", "flowers"]:
		if not m.has(k):
			m[k] = []
	for k in ["visit", "seen", "vase"]:
		if not m.has(k):
			m[k] = {}
	return m


static func graves() -> Array:
	return st()["graves"]


static func grave(id: String) -> Dictionary:
	for g in graves():
		if str(g["id"]) == id:
			return g
	return {}


## Graves that stand in the graveyard right now (from the morning of the funeral).
static func standing() -> Array:
	return graves().filter(func(g): return Game.day() >= int(g.get("funeral_day", 0)))


# ------------------------------------------------------------------ death and funeral
## Called by Hire._resolve when a hireling dies. Keeps a full record for the headstone.
static func on_death(h: Dictionary, dest: Dictionary) -> Dictionary:
	if not grave(str(h["id"])).is_empty():
		return grave(str(h["id"]))
	var hist: Array = (h.get("history", []) as Array).duplicate(true)
	var best := ""
	for sk in DB.work_skills:
		if best == "" or SkillSys.level(h["skills"], sk) > SkillSys.level(h["skills"], best):
			best = sk
	var ach := []
	ach.append("Served the forge for %d day%s" % [maxi(1, Game.day() - int(h.get("hired_day", Game.day()))), "" if Game.day() - int(h.get("hired_day", 0)) == 1 else "s"])
	if best != "":
		ach.append("%s, level %d" % [SkillSys.skill_name(best), SkillSys.level(h["skills"], best)])
	var trips := int(h.get("expeditions", 0))
	if trips > 0:
		ach.append("%d expedition%s into the wilds" % [trips, "" if trips == 1 else "s"])
	var hauls := 0
	for e in hist:
		if str(e.get("outcome", "")).begins_with("success"):
			hauls += 1
	if hauls > 0:
		ach.append("%d full haul%s brought home" % [hauls, "" if hauls == 1 else "s"])
	for ln in h.get("log", []):
		if str(ln).contains("identified") or str(ln).contains("brewed") or str(ln).contains("prepared"):
			ach.append(str(ln).get_slice("— ", 1).capitalize())
			break
	var g := {"id": str(h["id"]), "name": str(h["name"]), "look": str(h.get("look", h["id"])), "race": str(h.get("race", "")),
		"personality": str(h.get("personality", "")), "hired_day": int(h.get("hired_day", 1)), "died_day": Game.day(),
		"dest": str(dest.get("id", "")), "dest_name": str(dest.get("name", "the wilds")), "expeditions": trips,
		"best_skill": best, "achievements": ach, "history": hist, "plot": graves().size() % PLOTS,
		"funeral_day": Game.day() + 1, "funeral_done": false, "attended": false}
	graves().append(g)
	Chronicle.add("death", "%s died at %s. Father Oswin will bury them tomorrow at ten." % [g["name"], g["dest_name"]],
		{"hireling": g["id"], "place": g["dest"]}, true)
	TalkMarkers.flag("oswin", "The funeral for %s is tomorrow at ten, in the graveyard" % g["name"])
	Events.toast.emit("Father Oswin will bury %s tomorrow at ten, in the graveyard south of the chapel. You are welcome to come." % g["name"], "info")
	return g


## The grave whose funeral is today and not yet held ({} otherwise).
static func funeral_today() -> Dictionary:
	for g in graves():
		if int(g["funeral_day"]) == Game.day() and not bool(g["funeral_done"]):
			return g
	return {}


## Is the service under way (10:00–11:00 on the funeral day)?
static func funeral_now() -> bool:
	return not funeral_today().is_empty() and Game.hour() == FUNERAL_HOUR


## Who comes to the graveyard: the priest, the other hands and a handful of villagers.
static func mourners() -> Array:
	var g := funeral_today()
	if g.is_empty():
		return []
	var out := ["oswin"]
	for h in Hire.list():
		if str(h["id"]) != str(g["id"]) and str(h["status"]) in ["working", "injured"]:
			out.append(str(h["id"]))
	for v in VILLAGE_MOURNERS:
		if out.size() >= 9:
			break
		if not DB.character(v).is_empty():
			out.append(v)
	return out


## Schedule override (VillageWorld.spot_for): during the morning of a funeral the mourners walk to the
## graveyard at nine and stand around the grave from ten until eleven. "" = no override.
static func funeral_spot(id: String) -> String:
	var g := funeral_today()
	if g.is_empty():
		return ""
	var h := Game.hour()
	if h < FUNERAL_HOUR - 1 or h > FUNERAL_HOUR:
		return ""
	var i := mourners().find(id)
	if i < 0:
		return ""
	var plot := int(g["plot"])
	return ("funeral_%d_priest" % plot) if i == 0 else ("funeral_%d_%d" % [plot, i - 1])


## The smith stood with the village at the graveside.
static func attend() -> void:
	var g := funeral_today()
	if g.is_empty():
		return
	g["attended"] = true
	var who := mourners()
	_close_funeral(g)
	Game.journal("You stood at the graveside as Father Oswin laid %s to rest. Somebody had brought %s's old work gloves; they went into the earth too." % [g["name"], g["name"]])
	Chronicle.add("funeral", "%s was buried in the graveyard. The smith was there." % g["name"], {"hireling": g["id"]})
	for m: String in who:
		if str(DB.character(m).get("kind", "")) == "villager":
			Social.change(m, 2.0, 1.0)   # quietly: the village noticed who came


static func _close_funeral(g: Dictionary) -> void:
	g["funeral_done"] = true
	TalkMarkers.clear("oswin")


# ------------------------------------------------------------------ clock
static func on_hour(h: int) -> void:
	if Game.state.is_empty() or not Game.state.has("memorial"):
		return
	var g := funeral_today()
	if not g.is_empty() and h == 8:
		Events.toast.emit("This morning at ten Father Oswin buries %s in the graveyard south of the chapel." % g["name"], "info")
	if not g.is_empty() and h == FUNERAL_HOUR + 1:
		_close_funeral(g)
		Game.journal("The village buried %s this morning. You were not there." % g["name"])
		Chronicle.add("funeral", "%s was buried in the graveyard." % g["name"], {"hireling": g["id"]})


static func on_day() -> void:
	if not Game.state.has("memorial"):
		return
	var m := st()
	# a funeral nobody closed (the day was slept through)
	for g in graves():
		if not bool(g["funeral_done"]) and Game.day() > int(g["funeral_day"]):
			_close_funeral(g)
	# last night's visitor, unmet, left wildflowers on the step
	var v: Dictionary = m["visit"]
	if not v.is_empty():
		if not bool(v.get("met", false)) and Game.day() > int(v["day"]):
			var g2 := grave(str(v["id"]))
			(m["flowers"] as Array).append({"id": str(v["id"]), "name": str(g2.get("name", "")), "day": Game.day()})
			Chronicle.add("ghost", "Someone left a bunch of wildflowers outside the smithy door in the night.", {"hireling": v["id"]})
			Events.toast.emit("There are wildflowers on the smithy step this morning. Nobody saw who left them.", "info")
		m["visit"] = {}
	_maybe_visit()


static func _maybe_visit() -> void:
	var m := st()
	var eligible := graves().filter(func(g): return bool(g["funeral_done"]) and Game.day() - int(g["died_day"]) >= GHOST_AFTER_DAYS)
	if eligible.is_empty() and not force_ghost:
		return
	if not funeral_today().is_empty():
		return
	if Game.day() - int(m.get("last_visit_day", -99)) < GHOST_GAP_DAYS and not force_ghost:
		return
	if not force_ghost and randf() >= GHOST_CHANCE:
		return
	if eligible.is_empty():
		eligible = graves()
	if eligible.is_empty():
		force_ghost = false
		return
	var g: Dictionary = eligible[randi() % eligible.size()]
	m["visit"] = {"id": str(g["id"]), "day": Game.day(), "met": false}
	m["last_visit_day"] = Game.day()
	force_ghost = false


## A ghost is in the workshop now: {} or the grave record.
static func ghost_now() -> Dictionary:
	if not Game.state.has("memorial"):
		return {}
	var v: Dictionary = st()["visit"]
	if v.is_empty() or bool(v.get("met", false)) or int(v["day"]) != Game.day() or Game.hour() < GHOST_FROM_HOUR:
		return {}
	return grave(str(v["id"]))


const GHOST_LINES := {
	"mining": ["\"The deep seams still sing, smith. I hear them from here.\"", "\"Keep the lamps trimmed down there. Mind the props.\""],
	"smithing": ["\"Your anvil rings truer than it did. I listened at the door.\"", "\"Quench it slower. You always rush the quench.\""],
	"alchemy": ["\"The moonwort by the stream flowers early this year. Pick it before the frost.\"", "\"Never trust a draught that smells of nothing.\""],
	"runecraft": ["\"The blanks split cleaner if you wet the chisel first.\"", "\"I can read the runes better now. Funny, that.\""],
	"travelling": ["\"The road is long, but the inn at the end of it was always warm.\"", "\"I still know every milestone between here and the coast.\""],
	"relic_hunting": ["\"Old things remember us, smith. I am an old thing now.\"", "\"There's a coin under the third heap. Always was.\""],
}


## Talking to the ghost: a warm line about their life or work. Marks the visit met.
static func meet_ghost() -> String:
	var g := ghost_now()
	if g.is_empty():
		return ""
	var m := st()
	(m["visit"] as Dictionary)["met"] = true
	m["seen"][g["id"]] = int(m["seen"].get(g["id"], 0)) + 1
	var pool: Array = GHOST_LINES.get(str(g.get("best_skill", "")), ["\"It is quiet here. I like the sound of the forge.\""])
	var line: String = pool[(int(m["seen"][g["id"]]) - 1) % pool.size()]
	line += "\n" + ["\"Don't grieve too long. Light the forge.\"", "\"Tell Hilde I still owe her for that last ale.\"",
		"\"You were a fair master. That counts for a lot.\""][absi(str(g["id"]).hash() + Game.day()) % 3]
	Game.journal("%s's ghost came by the workshop tonight. %s" % [g["name"], line])
	Chronicle.add("ghost", "The smith spoke with the ghost of %s in the workshop." % g["name"], {"hireling": g["id"]})
	return line


# ------------------------------------------------------------------ flowers and the vase
static func flowers_at_door() -> Array:
	return st()["flowers"] if Game.state.has("memorial") else []


## Picks up the wildflowers at the smithy door into the inventory. Returns the item ({} if none).
static func collect_flowers() -> Dictionary:
	var fl: Array = st()["flowers"]
	if fl.is_empty():
		return {}
	var f: Dictionary = fl.pop_front()
	var it := Items.make("flowers_remembrance")
	it["from_id"] = str(f["id"])
	it["from_name"] = str(f["name"])
	it["name"] = "Wildflowers (from %s)" % f["name"] if str(f["name"]) != "" else "Wildflowers"
	Game.add_item(it, false)
	Events.inventory_changed.emit()
	Events.toast.emit("You gather up the wildflowers. They smell of the meadow by Ironroot. Put them in the vase in your quarters.", "good")
	return it


static func flowers_in_pack() -> Dictionary:
	for it in Game.inventory():
		if str(it.get("def", "")) == "flowers_remembrance":
			return it
	return {}


## Puts the first bunch of remembrance flowers from the pack into the vase.
static func place_in_vase() -> bool:
	var it := flowers_in_pack()
	if it.is_empty():
		return false
	Game.inventory().erase(it)
	var name := str(it.get("from_name", ""))
	st()["vase"] = {"id": str(it.get("from_id", "")), "name": name, "day": Game.day()}
	Game.journal("You put the wildflowers in the little vase by your bed%s." % ((" — for " + name) if name != "" else ""))
	Events.inventory_changed.emit()
	return true


static func vase() -> Dictionary:
	return st()["vase"] if Game.state.has("memorial") else {}


static func vase_text() -> String:
	var v := vase()
	if v.is_empty():
		return "A small glazed vase, empty. It would hold a handful of flowers."
	var g := grave(str(v["id"]))
	var t := "Wildflowers, set here on day %d." % int(v["day"])
	if not g.is_empty():
		t += " They were left on the step by %s, who worked the %s for you and died at %s on day %d." % [g["name"],
			SkillSys.skill_name(str(g.get("best_skill", "mining"))).to_lower(), g["dest_name"], int(g["died_day"])]
	return t


## Headstone text for the grave inspect window.
static func epitaph(g: Dictionary) -> String:
	var lines := ["[font_size=30][b]%s[/b][/font_size]" % g["name"],
		"[i]%s · hired day %d · died day %d at %s[/i]" % [g.get("race", ""), int(g["hired_day"]), int(g["died_day"]), g["dest_name"]]]
	if str(g.get("personality", "")) != "":
		lines.append("[color=#5e421c]%s[/color]" % g["personality"])
	lines.append("")
	for a in g.get("achievements", []):
		lines.append("❧ " + str(a))
	var hist: Array = g.get("history", [])
	if not hist.is_empty():
		lines.append("")
		for e in hist.slice(maxi(0, hist.size() - 4)):
			lines.append("[color=#5e421c]Day %d — %s: %s[/color]" % [int(e["day"]), DB.destinations.get(str(e["dest"]), {}).get("name", e["dest"]),
				HirelingsPanel.OUTCOME.get(str(e["outcome"]), str(e["outcome"]))])
	if bool(g.get("attended", false)):
		lines.append("\n[i]You stood at the graveside.[/i]")
	var seen := int(st()["seen"].get(g["id"], 0))
	if seen > 0:
		lines.append("[i]You have spoken with their ghost %s.[/i]" % ("once" if seen == 1 else "%d times" % seen))
	return "\n".join(lines)
