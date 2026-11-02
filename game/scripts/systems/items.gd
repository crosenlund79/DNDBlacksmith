## Items — item instances, rarity presentation and tooltips.
## EN: An item instance is a Dictionary {uid, def, name, qty, rarity, quality, stats, affixes, star,
##     arcane_glow, sockets, ...}. Rarity uses the Diablo-style colour families: Common white,
##     Magic blue, Rare yellow, Legendary orange (with a star), Unique gold/brown, Set green.
## DA: En genstand er en Dictionary. Sjældenhed bruger Diablo-farvefamilierne: almindelig hvid,
##     magisk blå, sjælden gul, legendarisk orange (med stjerne), unik guld/brun og sæt grøn.
class_name Items
extends RefCounted

const RARITIES := ["common", "magic", "rare", "legendary", "unique", "set"]
const RARITY_LABEL := {"common": "Common", "magic": "Magic", "rare": "Rare", "legendary": "Legendary", "unique": "Unique", "set": "Set"}
# text on dark tooltips / panels
const COL_DARK := {"common": Color("#efe4cc"), "magic": Color("#8aa6f2"), "rare": Color("#f0d060"),
	"legendary": Color("#ffa050"), "unique": Color("#dab470"), "set": Color("#7ccc80")}
# text on parchment
const COL_LIGHT := {"common": Color("#20140c"), "magic": Color("#24409a"), "rare": Color("#735800"),
	"legendary": Color("#9e3a0c"), "unique": Color("#5e421c"), "set": Color("#26622f")}
# slot borders / glows
const COL_BORDER := {"common": Color("#6e6250"), "magic": Color("#3a64d8"), "rare": Color("#d4b020"),
	"legendary": Color("#ff7a1e"), "unique": Color("#a87a3a"), "set": Color("#3aa850")}

const AFFIXES := [
	{"id": "keen", "prefix": "Keen", "stat": "attack", "lo": 2, "hi": 5, "for": ["weapon"]},
	{"id": "embers", "suffix": "of Embers", "stat": "fire", "lo": 2, "hi": 6, "for": ["weapon"]},
	{"id": "haste", "suffix": "of Haste", "stat": "speed", "lo": 4, "hi": 10, "for": ["weapon", "gloves", "boots"]},
	{"id": "warded", "prefix": "Warded", "stat": "protection", "lo": 2, "hi": 5, "for": ["armor", "shield", "helmet", "gloves", "boots", "belt"]},
	{"id": "bear", "suffix": "of the Bear", "stat": "durability", "lo": 15, "hi": 40, "for": ["weapon", "armor", "shield", "helmet", "boots", "gloves", "belt"]},
	{"id": "fortune", "suffix": "of Fortune", "stat": "luck", "lo": 3, "hi": 9, "for": ["ring", "amulet", "belt", "gloves"]},
	{"id": "vigor", "suffix": "of Vigor", "stat": "vitality", "lo": 4, "hi": 12, "for": ["armor", "amulet", "ring", "belt", "helmet"]},
	{"id": "sage", "prefix": "Sage's", "stat": "magic", "lo": 2, "hi": 6, "for": ["ring", "amulet", "weapon", "helmet"]},
	{"id": "frost", "suffix": "of Rime", "stat": "frost", "lo": 2, "hi": 6, "for": ["weapon"]},
	{"id": "stalwart", "prefix": "Stalwart", "stat": "ward", "lo": 2, "hi": 5, "for": ["armor", "shield"]},
]
const LEGEND_NAMES := ["Emberfang", "Widow's Promise", "The Last Bell", "Ashbrand", "Oathkeeper", "Gravewarden",
	"Hearthguard", "Nightglass", "The Cinder Saint", "Brindle's Mercy", "Wyrmbane", "Sorrowsteel"]
const LEGEND_TITLES := ["of the Forgotten", "Forged in Ash", "the Unbroken", "of Old Brannoc", "the Ember-Sworn", "of the Barrow Kings"]


static func def(item: Dictionary) -> Dictionary:
	return DB.item(item.get("def", ""))


static func is_equipment(item: Dictionary) -> bool:
	return def(item).get("slot") != null and def(item).get("slot", "") != ""


static func slot(item: Dictionary) -> String:
	var s: Variant = def(item).get("slot")
	return s if s is String else ""


static func make(def_id: String, opts := {}) -> Dictionary:
	var d := DB.item(def_id)
	if d.is_empty():
		Log.error("Unknown item def: " + def_id)
		return {}
	var it := {
		"uid": Game.new_uid(), "def": def_id, "name": d.get("name", def_id), "qty": int(opts.get("qty", 1)),
		"rarity": opts.get("rarity", "common"), "quality": float(opts.get("quality", 70.0)),
		"stats": {}, "affixes": [], "star": false, "arcane_glow": d.get("tags", []).has("arcane"),
		"sockets": [], "crafted_by": opts.get("crafted_by", ""),
	}
	if d.get("tags", []).has("unique"):
		it["rarity"] = "unique"
	elif d.get("tags", []).has("set"):
		it["rarity"] = "set"
	_base_stats(it, d, float(it["quality"]), opts.get("dice", {}))
	if it["rarity"] in ["magic", "rare", "legendary"] and is_equipment(it):
		apply_rarity(it, it["rarity"])
	return it


## Base statistics from definition, craftsmanship quality and dice rolls.
## quality is a percentage (can exceed 100). dice: {"edge"/"guard": d20, "temper": d12}.
static func _base_stats(it: Dictionary, d: Dictionary, quality: float, dice: Dictionary, skill_lvl := 0) -> void:
	var st: Dictionary = d.get("stats", {})
	var q := clampf(quality / 100.0 * 0.85, 0.0, 1.15)
	var skill_mult := 1.0 + 0.01 * skill_lvl
	var main_roll: int = int(dice.get("edge", dice.get("guard", 10)))
	var dice_f := 0.85 + (clampi(main_roll, 1, 20) - 1) / 19.0 * 0.35
	var temper: int = int(dice.get("temper", 6))
	var out := {}
	for key in st:
		var v: Variant = st[key]
		if v is Array:
			out[key] = int(round(lerpf(float(v[0]), float(v[1]), q) * dice_f * skill_mult))
		elif key == "durability":
			out[key] = int(round(float(v) * (0.6 + 0.4 * minf(quality / 100.0, 1.25)) * (0.9 + clampi(temper, 1, 12) / 12.0 * 0.2)))
		else:
			out[key] = int(round(float(v) * (0.7 + 0.3 * minf(quality / 100.0, 1.3))))
	if out.has("durability"):
		out["durability_max"] = out["durability"]
	it["stats"] = out


static func apply_rarity(it: Dictionary, rarity: String) -> void:
	it["rarity"] = rarity
	var n: int = {"common": 0, "magic": 1, "rare": 2, "legendary": 3}.get(rarity, 0)
	var s := slot(it)
	var pool := AFFIXES.filter(func(a): return a["for"].has(s))
	pool.shuffle()
	var prefix := ""
	var suffix := ""
	for i in min(n, pool.size()):
		var a: Dictionary = pool[i]
		var val := randi_range(int(a["lo"]), int(a["hi"])) * (2 if rarity == "legendary" else 1)
		it["affixes"].append({"id": a["id"], "stat": a["stat"], "value": val})
		if a.has("prefix") and prefix == "":
			prefix = a["prefix"]
		elif a.has("suffix") and suffix == "":
			suffix = a["suffix"]
	var base_name: String = DB.item(it["def"]).get("name", it["def"])
	if rarity == "legendary":
		it["star"] = true
		for k in it["stats"]:
			if k in ["attack", "protection", "magic"]:
				it["stats"][k] = int(round(it["stats"][k] * 1.15))
		it["name"] = "%s, %s" % [LEGEND_NAMES.pick_random(), base_name]
		it["epithet"] = LEGEND_TITLES.pick_random()
	elif rarity == "rare":
		it["name"] = ("%s %s %s" % [prefix, base_name, suffix]).strip_edges()
	elif rarity == "magic":
		it["name"] = ("%s %s" % [prefix, base_name]).strip_edges() if prefix != "" else ("%s %s" % [base_name, suffix]).strip_edges()


## Rarity from craftsmanship and the fortune die (d100). Formula and thresholds: data/crafting.json.
static func rarity_from(quality: float, fortune: int, bonus := 0.0) -> String:
	return str(Crafting.rarity_eval(quality, fortune, bonus)["rarity"])


## Material tier of an item (1 iron/leather … 4 adamantine) — orders can ask for "steel or better".
static func tier(it: Dictionary) -> int:
	var id := str(it.get("def", ""))
	if id.contains("adamantine"):
		return 4
	if id.contains("mithril") or id.contains("starsteel") or id in ["grimhold", "wyvernscale_pauldron"]:
		return 3
	if id.contains("steel") or id.contains("emberwarden") or id in ["ring_garnet", "amulet_sapphire", "hood_embroidered", "gloves_warded"]:
		return 2
	return 1


const TIER_WORD := {1: "any material", 2: "steel or better", 3: "mithril or starsteel", 4: "adamantine"}


static func stat(it: Dictionary, key: String) -> int:
	var v := int(it.get("stats", {}).get(key, 0))
	for a in it.get("affixes", []):
		if a["stat"] == key:
			v += int(a["value"])
	return v


## Single number used by adventurers/customers to judge gear.
static func score(it: Dictionary) -> float:
	if it.is_empty():
		return 0.0
	return stat(it, "attack") + stat(it, "protection") * 1.2 + stat(it, "magic") * 1.5 + stat(it, "fire") \
		+ stat(it, "frost") + stat(it, "ward") * 1.2 + stat(it, "vitality") * 0.5 + stat(it, "speed") * 0.4 \
		+ float(it.get("quality", 70)) * 0.05


static func value(it: Dictionary) -> int:
	var base := float(def(it).get("value", 5))
	var mult: float = {"common": 1.0, "magic": 1.8, "rare": 3.0, "legendary": 7.0, "unique": 9.0, "set": 6.0}.get(it.get("rarity", "common"), 1.0)
	var qm := 0.6 + float(it.get("quality", 70)) / 100.0 * 0.6
	return int(round(base * mult * qm)) * int(it.get("qty", 1))


static func display_name(it: Dictionary) -> String:
	var n: String = it.get("name", "?")
	if int(it.get("qty", 1)) > 1:
		n += " ×%d" % int(it["qty"])
	return ("★ " + n) if it.get("star", false) else n


static func color(it: Dictionary, dark := true) -> Color:
	var r: String = it.get("rarity", "common")
	return (COL_DARK if dark else COL_LIGHT).get(r, Color.WHITE)


static func icon_id(it: Dictionary) -> String:
	return "icons/" + str(def(it).get("icon", it.get("def", "")))


static func type_label(it: Dictionary) -> String:
	var t: String = def(it).get("type", "")
	return {"weapon": "Weapon", "shield": "Shield", "armor_metal": "Metal Armour", "armor_leather": "Leather Armour",
		"helmet": "Helmet", "boots": "Boots", "gloves": "Gloves", "belt": "Belt", "ring": "Ring", "amulet": "Amulet",
		"runestone": "Runestone", "material": "Material", "potion": "Alchemy", "relic": "Relic", "container": "Container"}.get(t, t.capitalize())


## BBCode tooltip for dark panels.
static func tooltip(it: Dictionary) -> String:
	var c := color(it).to_html(false)
	var lines: Array[String] = []
	lines.append("[font_size=26][color=#%s]%s[/color][/font_size]" % [c, display_name(it)])
	if it.has("epithet"):
		lines.append("[i][color=#%s]%s[/color][/i]" % [c, it["epithet"]])
	lines.append("[color=#%s]%s %s[/color]" % [c, RARITY_LABEL.get(it.get("rarity", "common"), ""), type_label(it)])
	var st: Dictionary = it.get("stats", {})
	var names := {"attack": "Attack", "protection": "Protection", "magic": "Magic", "fire": "Fire", "frost": "Frost",
		"ward": "Ward", "heal": "Healing", "edge": "Edge", "smithing": "Smithing"}
	for k in names:
		var v := stat(it, k)
		if v != 0:
			lines.append("%s  [b]%d[/b]" % [names[k], v])
	if st.has("durability"):
		lines.append("Durability  %d / %d" % [int(st["durability"]), int(st.get("durability_max", st["durability"]))])
	for a in it.get("affixes", []):
		if not names.has(a["stat"]):
			lines.append("[color=#8aa6f2]+%d %s[/color]" % [int(a["value"]), str(a["stat"]).capitalize()])
	for s in it.get("sockets", []):
		lines.append("[color=#ffc070]◆ Set with %s[/color]" % DB.item(s).get("name", s))
	if it.get("arcane_glow", false):
		lines.append("[color=#b89cff]Arcane markings glow along the metal.[/color]")
	if it.has("quality") and (is_equipment(it) or def(it).get("type") in ["potion", "runestone"]):
		var q := float(it["quality"])
		var qc := "#ffa050" if q > 100 else ("#efe4cc" if q >= 70 else "#c09070")
		lines.append("Craftsmanship  [color=%s]%d%%[/color]" % [qc, int(round(q))])
	if it.has("dice_log"):
		lines.append("[color=#a89a80][i]Dice: %s[/i][/color]" % it["dice_log"])
	if it.has("craft"):
		var cr: Dictionary = it["craft"]
		lines.append("[color=#a89a80][i]%s · %d operations · %s dice%s[/i][/color]" % [cr.get("material", ""), cr.get("ops", []).size(),
			cr.get("dice_mode", "digital"), " · Masterwork" if cr.get("masterwork", false) else ""])
	if it.get("ancient", false):
		lines.append("[color=#dab470][i]Ancient work, recovered from the barrows.[/i][/color]")
	if it.has("bound"):
		var bd: Dictionary = it["bound"]
		lines.append("[color=#b89cff]Bound into the metal: %s (+%d %s)[/color]" % [bd.get("name", ""), int(bd.get("value", 0)), str(bd.get("stat", "")).capitalize()])
	if it.has("coating"):
		var co: Dictionary = it["coating"]
		lines.append("[color=#ffc070]Treated with %s: +%d %s for %d more expedition%s[/color]" % [co.get("name", ""), int(co.get("value", 0)), str(co.get("stat", "")).capitalize(), int(co.get("uses", 0)), "" if int(co.get("uses", 0)) == 1 else "s"])
	if Regions.is_unidentified(it):
		lines.append("[color=#c09070][i]Unidentified — study it to learn what it is.[/i][/color]")
	if it.get("trade", false):
		lines.append("[color=#a89a80][i]Set aside for the next trade run.[/i][/color]")
	if it.get("crafted_by", "") != "":
		lines.append("[color=#a89a80][i]Made by %s[/i][/color]" % it["crafted_by"])
	var desc: String = it.get("desc", def(it).get("desc", ""))
	if desc != "":
		lines.append("[i][color=#c8b898]%s[/color][/i]" % desc)
	lines.append("[color=#dab470]Value %d g[/color]" % value(it))
	return "\n".join(lines)
