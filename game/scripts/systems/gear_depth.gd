## GearDepth — what exceptional equipment DOES (R5 "Equipment Depth": EQ-022, EQ-023, EQ-025, EQ-027, EQ-029, EQ-033,
## EQ-040, EQ-052; decision 10, the audit's bounded default).
## EN: Before R5 an affix was a flat number, and several of the numbers changed nothing. Now:
##     • Affix EFFECTS (twelve): every affix keeps its stat and adds one effect that changes a real fight or decision —
##         keen      critical hits on 19–20 (the wearer's weapon finds the gap);
##         embers    a hit may set the foe alight: +the fire value again (25 %);
##         haste     a quick second strike: speed × 2 % chance of half a blow more;
##         warded    an enemy's critical hit is turned to an ordinary one;
##         bear      the piece wears at half the rate;
##         fortune   luck × 3 % per find of one more piece from the same spoils;
##         vigor     vitality adds hit points from any piece (before: only an amulet);
##         sage      spells strike truer (+1 to hit);
##         rime      a struck foe is chilled: −2 on its next attack;
##         stalwart  morale lost to defeat and grief is halved;
##         leech     a hit heals the wearer by the leech value;
##         thorns    a foe that strikes the wearer takes the thorns value back.
##     • SETS (three small sets): matched pieces of one set from one maker's mark, worn together —
##         Hearthguard  (steel longsword, steel cuirass, steel tower shield): 2 — +4 protection; 3 — "stands fast":
##                      once a fight, a blow that would fell the wearer leaves them standing at 1;
##         Wayfarer's   (ranger boots, travel cloak, leather belt): 2 — half the road's wear; 3 — +2 defence;
##         Spellwright's (scholar's robe, spellweaver gloves, embroidered hood): 2 — +3 magic; 3 — spells +1 to hit
##                      and critical on 19–20.
##     • MAGIC BOUNDARIES (EQ-033): runes are permanent socketed effects (Crafting.socket, at most two); ARCANA are
##       permanent deep properties bound into an existing piece by an arcanist only (Refinement "enchant", ARCANA
##       below); alchemy is temporary (coatings and oils, a few trips). One kind never imitates another.
##     • STATES (EQ-040, decision 11): worn → broken (half strength; mended by a reforge) → disabled (unusable;
##       restoration only — Reliquary-eligible) → destroyed (only by a warned experiment; history in its tombstone).
##       An arcane property may be dormant (bound but asleep: no effect until an arcanist attunes it).
##     All reads are pure.
## DA: Hvad udstyr gør: tolv affiks-virkninger, tre sæt, magiens grænser og tilstande (brækket, ubrugelig).
class_name GearDepth
extends RefCounted

const EFFECTS := {
	"keen": {"name": "Keen", "text": "critical hits on 19–20"},
	"embers": {"name": "Embers", "text": "a hit may set the foe alight (25%: the fire value again)"},
	"haste": {"name": "Haste", "text": "a quick second strike (speed × 2% chance, half a blow)"},
	"warded": {"name": "Warded", "text": "an enemy's critical hit is turned"},
	"bear": {"name": "the Bear", "text": "wears at half the rate"},
	"fortune": {"name": "Fortune", "text": "luck × 3% per find of one more piece from the spoils"},
	"vigor": {"name": "Vigor", "text": "vitality adds hit points from any piece"},
	"sage": {"name": "Sage's", "text": "spells +1 to hit"},
	"frost": {"name": "Rime", "text": "a struck foe is chilled: −2 on its next attack"},
	"stalwart": {"name": "Stalwart", "text": "morale lost to defeat and grief is halved"},
	"leech": {"name": "the Leech", "text": "a hit heals the wearer by the leech value"},
	"thorns": {"name": "Thorns", "text": "a foe that strikes the wearer takes the thorns value back"},
}

## Deep arcane properties an arcanist can bind into an existing piece (Refinement "enchant").
const ARCANA := {
	"lambent": {"name": "Lambent", "stat": "magic", "lo": 3, "hi": 6, "for": ["weapon", "ring", "amulet", "helmet"], "text": "a steady inner light: +magic"},
	"leyward": {"name": "Leyward", "stat": "ward", "lo": 2, "hi": 5, "for": ["armor", "shield", "helmet", "cloak", "amulet"], "text": "the ley-lines turn the dead's blows: +ward"},
	"quickening": {"name": "Quickening", "stat": "speed", "lo": 6, "hi": 12, "for": ["weapon", "boots", "gloves"], "text": "time runs a little slower for its bearer: +speed"},
}

const SETS := {
	"hearthguard": {"name": "Hearthguard", "defs": ["sword_steel", "cuirass_steel", "shield_tower"],
		"two": {"protection": 4}, "three": "stands_fast", "text2": "+4 protection", "text3": "stands fast: once a fight, a felling blow leaves them standing"},
	"wayfarer": {"name": "Wayfarer's", "defs": ["boots_ranger", "cloak_travel", "belt_leather"],
		"two": {}, "two_effect": "road_wear", "three": "sure_footed", "text2": "half the road's wear", "text3": "+2 defence"},
	"spellwright": {"name": "Spellwright's", "defs": ["robe_scholar", "gloves_spellweaver", "hood_embroidered"],
		"two": {"magic": 3}, "three": "spellwright", "text2": "+3 magic", "text3": "spells +1 to hit and critical on 19–20"},
}


# ======================================================================= states
static func disabled(it: Dictionary) -> bool:
	return bool(it.get("disabled", false))


static func usable(it: Dictionary) -> bool:
	return not it.is_empty() and not disabled(it)


## "worn" / "broken" / "disabled" / "" — what the piece's state is.
static func state_word(it: Dictionary) -> String:
	if disabled(it):
		return "disabled"
	if bool(it.get("broken", false)):
		return "broken"
	return ""


## Disables a piece (a difficult failure): unusable until restored; its history says why.
static func disable(it: Dictionary, why: String) -> String:
	it["disabled"] = true
	it["disabled_info"] = {"day": Game.day(), "why": why}
	return Provenance.workshop(it, "disabled", "%s was left unusable — %s." % [Items.display_name(it), why], {"why": why})


# ======================================================================= effects
## The summed strength of an effect across the pieces an adventurer wears (affixes, active arcana; disabled pieces
## count for nothing).
static func fx(a: Dictionary, effect: String) -> int:
	var v := 0
	for slot in a.get("equipment", {}):
		var it: Dictionary = a["equipment"][slot]
		if not usable(it):
			continue
		for af in it.get("affixes", []):
			if str(af.get("id", "")) == effect:
				v += maxi(1, int(af.get("value", 1)))
	return v


static func has_fx(a: Dictionary, effect: String) -> bool:
	return fx(a, effect) > 0


## The value of an affix effect on one piece.
static func fx_of(it: Dictionary, effect: String) -> int:
	var v := 0
	for af in it.get("affixes", []):
		if str(af.get("id", "")) == effect:
			v += int(af.get("value", 0))
	return v


## Active arcana on a piece as stat bonuses (Items.base_stat adds them).
static func arcana_stat(it: Dictionary, key: String) -> int:
	var v := 0
	for ar in it.get("arcana", []):
		if str(ar.get("stat", "")) == key and str(ar.get("state", "active")) == "active":
			v += int(ar.get("value", 0))
	return v


# ======================================================================= sets
## The maker's mark that matches set pieces ("" for an unmarked piece).
static func _mark(it: Dictionary) -> String:
	if it.has("prov"):
		var m := str(Provenance.maker(it).get("mark", Provenance.maker(it).get("id", "")))
		if m != "":
			return m
	return str(it.get("crafted_by", ""))


## {set_id: n} — how many matched pieces of each set the adventurer wears (the largest group from one maker).
static func sets_worn(a: Dictionary) -> Dictionary:
	var out := {}
	for sid in SETS:
		var by_mark := {}
		for slot in a.get("equipment", {}):
			var it: Dictionary = a["equipment"][slot]
			if not usable(it) or not (SETS[sid]["defs"] as Array).has(str(it.get("def", ""))):
				continue
			var m := _mark(it)
			if m == "":
				continue
			if not by_mark.has(m):
				by_mark[m] = {}
			by_mark[m][str(it["def"])] = true
		var best := 0
		for m in by_mark:
			best = maxi(best, (by_mark[m] as Dictionary).size())
		if best >= 2:
			out[sid] = best
	return out


## Set bonus to a stat (2-piece bonuses).
static func set_stat(a: Dictionary, key: String) -> int:
	var v := 0
	var w := sets_worn(a)
	for sid in w:
		v += int((SETS[sid]["two"] as Dictionary).get(key, 0))
	return v


static func set_fx(a: Dictionary, effect: String) -> bool:
	var w := sets_worn(a)
	for sid in w:
		if int(w[sid]) >= 3 and str(SETS[sid].get("three", "")) == effect:
			return true
		if int(w[sid]) >= 2 and str(SETS[sid].get("two_effect", "")) == effect:
			return true
	return false


## The set a def belongs to ("" when none).
static func set_of(def: String) -> String:
	for sid in SETS:
		if (SETS[sid]["defs"] as Array).has(def):
			return str(sid)
	return ""


# ======================================================================= presentation (EQ-052)
## Lines for the tooltip: effects, arcana, set and state — shown apart from the plain stats.
static func lines(it: Dictionary) -> Array:
	var out := []
	for af in it.get("affixes", []):
		var e: Dictionary = EFFECTS.get(str(af.get("id", "")), {})
		if not e.is_empty():
			out.append("[color=#7fc4ff]%s[/color] — %s" % [str(e["name"]), str(e["text"])])
	for ar in it.get("arcana", []):
		var d: Dictionary = ARCANA.get(str(ar.get("id", "")), {})
		var dormant := str(ar.get("state", "active")) != "active"
		out.append("[color=#c59cff]Arcane: %s +%d %s[/color]%s — %s" % [str(d.get("name", ar.get("id", ""))), int(ar.get("value", 0)), str(ar.get("stat", "")),
			" [color=#a89a80](dormant — an arcanist can attune it)[/color]" if dormant else "", str(d.get("text", ""))])
	var sid := set_of(str(it.get("def", "")))
	if sid != "":
		var s: Dictionary = SETS[sid]
		out.append("[color=#7fd98a]Set: %s[/color] — with matched pieces from one maker: 2 — %s; 3 — %s" % [str(s["name"]), str(s["text2"]), str(s["text3"])])
	if disabled(it):
		out.append("[color=#ff8a6a]Disabled — unusable until restored (%s).[/color]" % str(it.get("disabled_info", {}).get("why", "")))
	return out
