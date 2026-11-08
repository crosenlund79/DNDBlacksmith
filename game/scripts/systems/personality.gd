## ItemSpirit — a few exceptional pieces wake up and, now and then, say something while the smith works on them.
## EN: Rare, not universal. Candidates are named legendaries (and unique/set pieces), Epic pieces, named blades,
##     cursed pieces and arcane pieces after a great deed; of those only about a third carry a spirit at all
##     (a roll fixed by the uid). Legendary, unique and cursed pieces wake the first time the world notices them;
##     the rest wake only after a significant event (a boss kill, an Epic deed, a name, its bearer's death, being
##     lost and found) — Lore events, heard through Events.lore_recorded. The personality type is chosen from the
##     piece's real history (kills → bloodthirsty/proud, dead bearers → melancholy, many hands → sarcastic, …),
##     settling for good with its first words (a piece that woke at the forge grows into its character).
##     State: Provenance.st(it)["spirit"] = {type, awakened_day, cause, last_line_t, lines_said, recent[]}; the
##     awakening is a Lore event ("awakened"). Global cooldown: Game.state["spirits"] = {last_t, said}.
##     Lines: data/personalities.json (tools/data/make_personalities.py), per type and context, with placeholders
##     filled from the real history; a seeded pick from uid + line counter + context, avoiding the last few.
##     speak(it, context) is the one entry point for every station and service; it returns the line or "".
##     SpiritVoice (scripts/ui/spirit_voice.gd) shows the line as an ink-violet bubble with the item's name.
##     Settings: gameplay/item_voices (on/off) and gameplay/item_voice_freq ("normal" | "rare"). Muted pieces
##     still wake (silently).
## DA: Enkelte enestående genstande vågner og siger af og til noget, mens smeden arbejder på dem. Typen vælges ud
##     fra genstandens virkelige historie; replikkerne fyldes med navne, steder og fjender fra den.
class_name ItemSpirit
extends RefCounted

const CHANCE := 30                 # % of candidates that carry a spirit (fixed by the uid)
const ITEM_COOLDOWN := 240         # game minutes between two lines of the same piece ("normal")
const GLOBAL_COOLDOWN := 90        # game minutes between any two lines
const RARE_MULT := 2.5             # "rare" frequency: longer cooldowns...
const SPEAK_CHANCE := {"normal": 65, "rare": 30}   # ...and fewer lines when off cooldown (%)
const MAKER_CHANCE := 18           # % of lines on the smith's own work that acknowledge the maker
const RECENT := 4                  # lines not repeated until this many others were said
const VOICE_KEY := "gameplay/item_voices"
const FREQ_KEY := "gameplay/item_voice_freq"
const TYPES := ["proud", "sarcastic", "impatient", "noble", "mischievous", "melancholy", "bloodthirsty", "wise", "vengeful", "dutiful"]
## Lore kinds that can wake a sleeping spirit.
const SIGNIFICANT := ["slew", "epic", "named", "death", "inherited", "recovered", "reunion", "honour", "legend"]
const CAUSE := {"slew": "a kill it will not forget", "epic": "a deed of Epic renown", "named": "it was given a name",
	"legend": "it was given a name", "death": "its bearer's death", "inherited": "it passed to an heir",
	"recovered": "it was lost and found again", "found": "it was lost and found again", "reunion": "it came home",
	"honour": "a deed of Epic renown"}
const PLACEHOLDERS := ["name", "maker", "first_owner", "last_owner", "deed", "place", "enemy", "days", "owners", "kills"]
const INK_VIOLET := Color("#3d2257")
const SFX := "sfx/spirit_whisper"

static var _wired := false
## The last line said (for SpiritVoice and tests): {uid, name, icon, type, context, text, serial}.
static var last: Dictionary = {}
static var serial := 0


# ------------------------------------------------------------------ wiring & state
## Listens to the Lore registry once (safe to call repeatedly). UIRoot calls it; tests call it.
static func wire() -> void:
	if _wired:
		return
	_wired = true
	Events.lore_recorded.connect(_on_lore)
	Events.chronicle_added.connect(_on_chronicle)


static func gst() -> Dictionary:
	if not Game.state.has("spirits"):
		Game.state["spirits"] = {"last_t": -100000, "said": 0}
	return Game.state["spirits"]


static func data() -> Dictionary:
	var d: Variant = DB.extra("personalities")
	return d if d is Dictionary else {}


static func voices_on() -> bool:
	return bool(Settings.get_value(VOICE_KEY, true))


static func frequency() -> String:
	return "rare" if str(Settings.get_value(FREQ_KEY, "normal")) == "rare" else "normal"


static func _roll(key: String) -> int:
	return absi(key.hash()) % 100


# ------------------------------------------------------------------ who may speak
static func cursed(it: Dictionary) -> bool:
	return bool(it.get("cursed", false)) or it.has("curse") or (Items.def(it).get("tags", []) as Array).has("cursed")


static func arcane(it: Dictionary) -> bool:
	var tags: Array = Items.def(it).get("tags", [])
	return bool(it.get("arcane_glow", false)) or tags.has("arcane") or it.has("bound")


## Wakes as soon as the world notices it (if destined): legendaries, uniques, set pieces, cursed pieces.
static func innate(it: Dictionary) -> bool:
	return str(it.get("rarity", "")) in ["legendary", "unique", "set"] or cursed(it)


## Could this piece ever carry a spirit? Ordinary pieces never do.
static func is_candidate(it: Dictionary) -> bool:
	if it.is_empty() or not Items.is_equipment(it):
		return false
	return innate(it) or it.has("epic") or it.has("title") or it.has("named") or arcane(it)


## The uid's fixed roll: only a minority of candidates carry a spirit.
static func destined(it: Dictionary) -> bool:
	return is_candidate(it) and _roll("spirit:%d" % int(it.get("uid", -1))) < CHANCE


static func spirit(it: Dictionary) -> Dictionary:
	if it.is_empty() or not it.has("prov"):
		return {}
	return (it["prov"] as Dictionary).get("spirit", {})


static func awake(it: Dictionary) -> bool:
	return not spirit(it).is_empty()


## Something significant already happened to it (Epic, a name, or a significant Lore event in its story).
static func has_deed(it: Dictionary) -> bool:
	if it.has("epic") or it.has("title") or it.has("named"):
		return true
	for e in Lore.events(Provenance.st(it).get("events", [])):
		if _significant(e, it):
			return true
	return false


static func _significant(e: Dictionary, it: Dictionary) -> bool:
	var k := str(e.get("kind", ""))
	if k in SIGNIFICANT:
		return true
	return k == "found" and Provenance.st(it).has("lost")


## The spirit, waking it now if it is destined and ready (innate, or after its deed). {} if it sleeps or has none.
static func ensure(it: Dictionary, cause := "") -> Dictionary:
	if it.is_empty():
		return {}
	var sp := spirit(it)
	if not sp.is_empty():
		return sp
	if not destined(it):
		return {}
	if innate(it) or has_deed(it):
		return awaken(it, cause if cause != "" else _likely_cause(it))
	return {}


## What woke it, when it is noticed only later: its latest significant event, or a fresh forging.
static func _likely_cause(it: Dictionary) -> String:
	var evs := Lore.events(Provenance.st(it).get("events", []))
	for i in range(evs.size() - 1, -1, -1):
		if _significant(evs[i], it):
			return str(evs[i].get("kind", ""))
	if it.has("epic"):
		return "epic"
	if Provenance.is_mine(it) and int(Provenance.maker(it).get("day", -1)) == Game.day():
		return "forged"
	return ""


## Wakes the spirit: its type from the history, and an "awakened" Lore event.
static func awaken(it: Dictionary, cause := "", place := "") -> Dictionary:
	var p := Provenance.st(it)
	if p.has("spirit"):
		return p["spirit"]
	var t := derive_type(it)
	var sp := {"type": t, "awakened_day": Game.day(), "cause": cause, "last_line_t": -100000, "lines_said": 0, "recent": []}
	p["spirit"] = sp
	var nm := str(it.get("name", "it"))
	var text := ""
	if cause == "forged":
		text = "As %s cooled at the Ironhand forge, something in the metal woke." % nm
	elif CAUSE.has(cause):
		text = "Something woke in %s after %s. It has begun, now and then, to speak." % [nm, CAUSE[cause]]
	else:
		text = "Something woke in %s. It has begun, now and then, to speak." % nm
	Lore.record("awakened", text, {"items": [it], "place": place, "importance": 2, "icon": "icons/rune",
		"data": {"type": t, "cause": cause}})
	return sp


## Lore hook: a forging or another event that involves a destined piece may wake it.
static func _on_lore(e: Dictionary) -> void:
	if Game.state.is_empty() or str(e.get("kind", "")) == "awakened":
		return
	for u in e.get("items", []):
		_consider(Game.find_uid_anywhere(int(u)), str(e.get("kind", "")), str(e.get("place", "")), _significant(e, Game.find_uid_anywhere(int(u))))


## News-feed hook: Epic distinction ("honour") and a blade's new name ("legend") reach the Chronicle.
static func _on_chronicle(e: Dictionary) -> void:
	if Game.state.is_empty() or not str(e.get("kind", "")) in ["honour", "legend"]:
		return
	var ref := str(e.get("refs", {}).get("item", ""))
	if ref.is_valid_int():
		_consider(Game.find_uid_anywhere(int(ref)), "epic" if str(e["kind"]) == "honour" else "named", "", true)


static func _consider(it: Dictionary, kind: String, place: String, significant: bool) -> void:
	if it.is_empty() or awake(it) or not destined(it):
		return
	if significant or innate(it) or it.has("epic") or it.has("title"):
		awaken(it, kind, place)


# ------------------------------------------------------------------ type from history
## The personality chosen from the piece's real history (deterministic: same history, same type).
static func derive_type(it: Dictionary) -> String:
	var sc := {}
	for t: String in TYPES:
		sc[t] = float(_roll("type:%d:%s" % [int(it.get("uid", -1)), t])) / 250.0   # tie-break, < 0.4
	var p := Provenance.st(it)
	for e in Lore.events(p.get("events", [])):
		match str(e.get("kind", "")):
			"slew":
				sc["bloodthirsty"] += 2.0
				sc["proud"] += 1.0
			"battle", "looted":
				sc["bloodthirsty"] += 1.0
			"survived":
				sc["dutiful"] += 2.0
			"epic", "named", "honour", "legend":
				sc["proud"] += 3.0
				sc["noble"] += 1.0
			"death":
				sc["melancholy"] += 3.0
				sc["vengeful"] += 1.5
			"inherited":
				sc["melancholy"] += 2.0
			"lost":
				sc["melancholy"] += 1.0
				sc["mischievous"] += 1.0
			"recovered", "found":
				sc["mischievous"] += 2.0
			"sold", "bought", "pawned", "redeemed":
				sc["sarcastic"] += 1.0
			"enchanted", "discovery":
				sc["wise"] += 1.0
			"commission", "reunion":
				sc["noble"] += 1.0
	var kills := int(it.get("kills", 0))
	sc["bloodthirsty"] += kills * 0.6
	sc["proud"] += kills * 0.2
	if it.has("epic") or it.has("title"):
		sc["proud"] += 2.0
	var hands := 0
	for o in p.get("owners", []):
		var oid := str(o.get("id", ""))
		if oid == Provenance.SMITH_ID or oid == "":
			continue
		hands += 1
		var a := Adv.get_a(oid)
		if a.is_empty():
			continue
		match str(a.get("cls", "")):
			"Wizard":
				sc["wise"] += 3.0
			"Cleric":
				sc["wise"] += 2.0
				sc["noble"] += 1.0
			"Paladin":
				sc["noble"] += 3.0
			"Fighter":
				sc["noble"] += 1.0
				sc["proud"] += 1.0
			"Rogue":
				sc["mischievous"] += 3.0
				sc["sarcastic"] += 1.0
			"Barbarian":
				sc["bloodthirsty"] += 3.0
			"Bard":
				sc["sarcastic"] += 2.0
				sc["mischievous"] += 1.0
			"Ranger":
				sc["impatient"] += 1.0
				sc["wise"] += 1.0
		if str(a.get("status", "")) == "dead":
			sc["melancholy"] += 3.0
	sc["sarcastic"] += maxi(0, hands - 2) * 1.5
	sc["mischievous"] += maxi(0, hands - 2) * 0.8
	if arcane(it):
		sc["wise"] += 2.0
	sc["wise"] += (it.get("sockets", []) as Array).size() * 0.5
	if cursed(it):
		sc["vengeful"] += 4.0
	var s := Items.slot(it)
	if s == "weapon":
		sc["impatient"] += 0.6
		sc["bloodthirsty"] += 0.3
		match Items.wtype(it):
			"axe", "mace":
				sc["impatient"] += 0.6
			"dagger":
				sc["sarcastic"] += 0.6
				sc["mischievous"] += 0.4
			"staff":
				sc["wise"] += 1.0
			"sword":
				sc["proud"] += 0.4
	elif s in ["ring", "amulet"]:
		sc["wise"] += 0.8
		sc["mischievous"] += 0.4
	elif s != "":
		sc["dutiful"] += 1.2
		sc["noble"] += 0.3
	var best := "proud"
	for t: String in TYPES:
		if float(sc[t]) > float(sc[best]):
			best = t
	return best


## A piece that woke young (at the forge) has little history yet: its character settles with its first words,
## from everything that happened to it until then. After that it never changes.
static func settle(it: Dictionary) -> void:
	var sp := spirit(it)
	if not sp.is_empty() and int(sp.get("lines_said", 0)) == 0:
		sp["type"] = derive_type(it)


static func type_name(t: String) -> String:
	return str(data().get("types", {}).get(t, {}).get("name", t.capitalize()))


# ------------------------------------------------------------------ placeholders from history
## Every placeholder that can be filled from the piece's real history (missing ones are left out).
static func facts(it: Dictionary) -> Dictionary:
	var f := {"name": str(it.get("name", "this piece"))}
	var p := Provenance.st(it)
	var mk: Dictionary = p.get("maker", {})
	if str(mk.get("id", "unknown")) != "unknown" and str(mk.get("name", "")) != "":
		f["maker"] = str(mk["name"])
	var hands := []
	for o in p.get("owners", []):
		if str(o.get("id", "")) not in [Provenance.SMITH_ID, ""]:
			hands.append(str(o.get("name", "")))
	if not hands.is_empty():
		f["first_owner"] = hands[0]
		f["last_owner"] = hands[hands.size() - 1]
	if hands.size() >= 2:
		f["owners"] = str(hands.size())
	if it.has("epic") and str(it["epic"].get("deed", "")) != "":
		f["deed"] = str(it["epic"]["deed"])
	var mk_day := int(mk.get("day", 0))
	if mk_day > 0 and Game.day() - mk_day >= 2:
		f["days"] = str(Game.day() - mk_day)
	var kills := int(it.get("kills", 0))
	var re := RegEx.new()
	re.compile("(?:[Ff]elled|[Ss]lew|killing blow on|[Kk]illed|[Dd]efeated) (.+?)(?: in | at | with |,|\\.|$)")
	var re_place := RegEx.new()
	re_place.compile(" in ([A-Z][^,.]+)")
	for e in Lore.events(p.get("events", [])):
		var d: Dictionary = e.get("data", {})
		var k := str(e.get("kind", ""))
		var txt := str(e.get("text", ""))
		if k == "slew":
			kills = maxi(kills, 1)
		for key: String in ["enemy", "boss", "foe"]:
			if str(d.get(key, "")) != "":
				f["enemy"] = str(d[key])
		if k in ["slew", "battle", "epic", "legend", "named", "note"] or txt.begins_with("Felled"):
			var m := re.search(txt)
			if m and not f.has("enemy") and m.get_string(1).length() < 40:
				f["enemy"] = m.get_string(1)
		var pl := str(e.get("place", ""))
		if pl != "" and pl != "brindlewick":
			f["place"] = place_name(pl, d)
		elif k in ["slew", "battle", "lost", "found", "recovered", "death"] or txt.begins_with("Felled"):
			var m2 := re_place.search(txt)
			if m2 and m2.get_string(1).length() < 40:
				f["place"] = m2.get_string(1).strip_edges()
	if kills > 0:
		f["kills"] = str(kills)
	if not f.has("enemy") and it.has("epic"):
		var m3 := re.search(str(it["epic"].get("deed", "")))
		if m3:
			f["enemy"] = m3.get_string(1)
	return f


static func place_name(id: String, d := {}) -> String:
	if str(d.get("place_name", "")) != "":
		return str(d["place_name"])
	var dest: Dictionary = DB.destinations.get(id, {})
	if str(dest.get("name", "")) != "":
		return str(dest["name"])
	return id.replace("_", " ").capitalize()


## The placeholders a line needs.
static func needs(text: String) -> Array:
	var out := []
	for k: String in PLACEHOLDERS:
		if text.contains("{" + k + "}"):
			out.append(k)
	return out


static func fill(text: String, f: Dictionary) -> String:
	var s := text
	for k: String in PLACEHOLDERS:
		if f.has(k):
			s = s.replace("{" + k + "}", str(f[k]))
	return s.substr(0, 1).to_upper() + s.substr(1)


# ------------------------------------------------------------------ choosing a line
static func norm_context(context: String) -> String:
	return str(data().get("aliases", {}).get(context, context))


## The authored lines of a type for a context (falling back along data "fallback"): [[id, text], ...].
static func lines_for(t: String, context: String) -> Array:
	var ty: Dictionary = data().get("types", {}).get(t, {})
	var ls: Dictionary = ty.get("lines", {})
	var ctx := norm_context(context)
	var out := []
	var guard := 0
	while out.is_empty() and ctx != "" and guard < 5:
		var arr: Array = ls.get(ctx, [])
		for i in arr.size():
			out.append(["%s:%s:%d" % [t, ctx, i], str(arr[i])])
		ctx = str(data().get("fallback", {}).get(ctx, "")) if out.is_empty() else ctx
		guard += 1
	return out


## The line this piece would say now in this context ({} when nothing fits). Pure: the same state gives the same line.
static func pick_line(it: Dictionary, context: String) -> Dictionary:
	var sp := spirit(it)
	if sp.is_empty():
		return {}
	var t := str(sp.get("type", "proud"))
	var uid := int(it.get("uid", -1))
	var n := int(sp.get("lines_said", 0))
	var f := facts(it)
	var ctx := norm_context(context)
	# now and then the smith's own work remembers who made it
	if ctx != "maker" and Provenance.is_mine(it) and f.has("maker") and _roll("maker:%d:%d:%s" % [uid, n, ctx]) < MAKER_CHANCE:
		var mk := _choose(lines_for(t, "maker"), f, sp, "%d:%d:maker" % [uid, n])
		if not mk.is_empty():
			return mk
	return _choose(lines_for(t, ctx), f, sp, "%d:%d:%s" % [uid, n, ctx])


static func _choose(pool: Array, f: Dictionary, sp: Dictionary, seed_key: String) -> Dictionary:
	var recent: Array = sp.get("recent", [])
	var ok := []
	var rich := []
	for l in pool:
		var need := needs(str(l[1]))
		var fillable := true
		for k in need:
			if not f.has(k):
				fillable = false
		if not fillable:
			continue
		if recent.has(str(l[0])):
			continue
		ok.append(l)
		if not need.is_empty():
			rich.append(l)
	if ok.is_empty():
		# everything was said lately: allow repeats rather than fall silent, but never the very last line
		for l in pool:
			var fill_ok := true
			for k in needs(str(l[1])):
				if not f.has(k):
					fill_ok = false
			if fill_ok and (recent.is_empty() or str(recent[recent.size() - 1]) != str(l[0])):
				ok.append(l)
		if ok.is_empty():
			return {}
	# prefer a line that speaks of the piece's own history when one fits
	var from: Array = rich if not rich.is_empty() and _roll("rich:" + seed_key) < 65 else ok
	var pick: Array = from[_roll("pick:" + seed_key) % from.size()]
	return {"id": str(pick[0]), "text": fill(str(pick[1]), f), "raw": str(pick[1])}


# ------------------------------------------------------------------ speaking
static func item_cooldown() -> int:
	return int(ITEM_COOLDOWN * (RARE_MULT if frequency() == "rare" else 1.0))


static func global_cooldown() -> int:
	return int(GLOBAL_COOLDOWN * (RARE_MULT if frequency() == "rare" else 1.0))


## Why the piece would stay quiet now ("" = it may speak): mute, no spirit, cooldowns.
static func quiet_reason(it: Dictionary) -> String:
	var sp := ensure(it)
	if sp.is_empty():
		return "no spirit"
	if not voices_on():
		return "muted"
	var now := Game.now()
	if now - int(sp.get("last_line_t", -100000)) < item_cooldown():
		return "item cooldown"
	if now - int(gst().get("last_t", -100000)) < global_cooldown():
		return "global cooldown"
	return ""


## The one entry point: the piece may say something about the work in `context` (repair, sharpen, reforge,
## forge, anvil, quench, enchant, treat, inspect, idle, maker). Returns the line said, or "".
## Wakes a destined piece silently even when item voices are off. force skips only the chance roll (so do a
## piece's first words); mute and cooldowns always apply.
static func speak(it: Dictionary, context: String, force := false) -> String:
	if it.is_empty() or Game.state.is_empty() or not Items.is_equipment(it):
		return ""
	if quiet_reason(it) != "":
		return ""
	var sp := spirit(it)
	var uid := int(it.get("uid", -1))
	settle(it)
	# the first words of a newly woken piece are never lost to the chance roll
	if not force and int(sp.get("lines_said", 0)) > 0 and _roll("chance:%d:%d:%s:%d" % [uid, int(sp.get("lines_said", 0)), context, Game.now()]) >= int(SPEAK_CHANCE[frequency()]):
		return ""
	var l := pick_line(it, context)
	if l.is_empty():
		return ""
	sp["last_line_t"] = Game.now()
	sp["lines_said"] = int(sp.get("lines_said", 0)) + 1
	if not sp.has("recent"):
		sp["recent"] = []
	(sp["recent"] as Array).append(str(l["id"]))
	while (sp["recent"] as Array).size() > RECENT:
		(sp["recent"] as Array).pop_front()
	gst()["last_t"] = Game.now()
	gst()["said"] = int(gst().get("said", 0)) + 1
	serial += 1
	last = {"uid": uid, "name": str(it.get("name", "")), "icon": Items.icon_id(it), "type": str(sp["type"]),
		"context": norm_context(context), "text": str(l["text"]), "id": str(l["id"]), "serial": serial}
	Audio.play(SFX, -9.0)
	return str(l["text"])


## Repairs at the grinding wheel: the piece a waiting customer brought (their own gear or a carried item).
static func repair_item(npc: String, part_id := "") -> Dictionary:
	var c := Shop.customer(npc)
	if c.is_empty():
		return {}
	var src: Dictionary = c
	if part_id != "":
		for pt in c.get("parts", []):
			if str(pt.get("pid", "")) == part_id:
				src = pt
	if src.has("own_slot"):
		var a := Adv.get_a(npc)
		var own: Dictionary = a.get("equipment", {}).get(str(src["own_slot"]), {})
		if not own.is_empty():
			return own
	return src.get("item", {})


## Convenience for the repair flows: the customer's piece may speak as it goes on the wheel.
static func speak_repair(npc: String, part_id := "") -> String:
	return speak(repair_item(npc, part_id), "repair")


## A one-line description for tooltips and history views ("" when it has no spirit).
static func describe(it: Dictionary) -> String:
	var sp := spirit(it)
	if sp.is_empty():
		return ""
	return "It speaks, now and then — %s (awake since day %d)." % [type_name(str(sp["type"])).to_lower(), int(sp.get("awakened_day", 0))]
