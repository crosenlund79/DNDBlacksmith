## DB — read-only game data loaded from res://data/*.json.
## EN: Items, stations, recipes, crafting balance, characters, destinations, loot tables, upgrades, skills, props,
##     dialogue and the village layout. Data-driven so content can grow without code changes.
## DA: Genstande, stationer, opskrifter, personer, destinationer, loot-tabeller, opgraderinger,
##     færdigheder, rekvisitter, dialog og landsbyens layout — datadrevet, så indhold kan vokse
##     uden kodeændringer.
extends Node

var items := {}
var stations := {}
var recipes := {}
var characters := {}
var destinations := {}
var upgrades := {}
var loot := {}
var skills := {}
var skill_list: Array = []
var work_skills: Array = []
var skill_curve := {}
var props := {}
var layout := {}
var dialogue := {}
var names := {}
var crafting := {}
var suppliers := {}
var expeditions := {}
var enemies := {}


func _ready() -> void:
	reload()


func _read(file: String) -> Variant:
	var path := "res://data/" + file
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		Log.error("Data file missing: " + path)
		return null
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed == null:
		Log.error("Data file is not valid JSON: " + path)
	return parsed


func _index(arr: Variant) -> Dictionary:
	var d := {}
	if arr is Array:
		for e in arr:
			d[e["id"]] = e
	return d


func reload() -> void:
	items = _index(_read("items.json"))
	stations = _index(_read("stations.json"))
	recipes = _index(_read("recipes.json"))
	characters = _index(_read("characters.json"))
	destinations = _index(_read("destinations.json"))
	upgrades = _index(_read("upgrades.json"))
	var lt: Variant = _read("loot_tables.json")
	loot = lt if lt is Dictionary else {}
	var sk: Variant = _read("skills.json")
	if sk is Dictionary:
		skill_list = sk["skills"]
		skills = _index(sk["skills"])
		work_skills = sk["work_skills"]
		skill_curve = sk["curve"]
	var pr: Variant = _read("props.json")
	props = pr if pr is Dictionary else {}
	var ly: Variant = _read("layout.json")
	layout = ly if ly is Dictionary else {}
	var dl: Variant = _read("dialogue.json")
	dialogue = dl if dl is Dictionary else {}
	var nm: Variant = _read("names.json")
	names = nm if nm is Dictionary else {}
	var cf: Variant = _read("crafting.json")
	crafting = cf if cf is Dictionary else {}
	var ex: Variant = _read("expeditions.json")
	expeditions = ex if ex is Dictionary else {}
	enemies = _index(expeditions.get("enemies", []))
	var sp: Variant = _read("suppliers.json")
	suppliers = sp if sp is Dictionary else {}
	Log.info("Data loaded: %d items, %d stations, %d recipes, %d characters" % [items.size(), stations.size(), recipes.size(), characters.size()])


## Any other data file (data/<name>.json), loaded once and cached — new systems use this instead of
## adding a field here: DB.extra("skilltree"), DB.extra("ironfront"), DB.extra("trade") …
var _extra := {}


func extra(name: String) -> Variant:
	if not _extra.has(name):
		var v: Variant = _read(name + ".json") if FileAccess.file_exists("res://data/" + name + ".json") else {}
		_extra[name] = v if v != null else {}
	return _extra[name]


func item(id: String) -> Dictionary:
	return items.get(id, {})


## A station's type data. Living Workshop (#37): a station INSTANCE id ("anvil#2", Property.type_of) resolves to its
## type's data, so every caller that holds an instance reads the right name, size, check and discipline.
func station(id: String) -> Dictionary:
	var i := id.find("#")
	return stations.get(id if i < 0 else id.substr(0, i), {})


func recipe(id: String) -> Dictionary:
	return recipes.get(id, {})


func character(id: String) -> Dictionary:
	return characters.get(id, {})


func building(id: String) -> Dictionary:
	for b in layout.get("buildings", []):
		if b["id"] == id:
			return b
	for a in layout.get("areas", []):
		if a["id"] == id:
			return a
	return {}
