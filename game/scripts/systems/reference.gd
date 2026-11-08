## Reference — the content of the Help & Reference guide, data-driven where possible.
## EN: entries() returns {tab, title, body (bbcode), icon, keys} for every topic the player may read;
##     search(q) filters across all tabs. No spoilers: recipes the smith does not know and secret or
##     rare items never seen are left out. Systems built in parallel (skill tree, property, Ironfront,
##     harbour) are described as general rules, with data lookups guarded.
## DA: Indholdet af hjælpe- og opslagsværket. Ingen spoilere.
class_name Reference
extends RefCounted

const TABS := [
	["basics", "Basics & Controls"], ["recipes", "Recipes"], ["stations", "Crafting Stations"], ["materials", "Materials"],
	["skilltree", "Skill-Tree Progression"], ["hirelings", "Hirelings"], ["careers", "Adventurer Careers"],
	["dice", "Dice & Rarity"], ["workshop", "Workshop Ownership & Editing"], ["ironfront", "Ironfront Rules"],
]

const SECRET_TAGS := ["secret", "rare", "unique", "set", "unidentified"]


# ======================================================================= seen items
static func seen() -> Dictionary:
	if not Game.state.has("seen_items"):
		Game.state["seen_items"] = {}
	return Game.state["seen_items"]


## Remembers every item definition currently in the smith's stores (called on inventory changes).
static func note_seen() -> void:
	if Game.state.is_empty():
		return
	var s := seen()
	for it in Game.inventory():
		s[str(it["def"])] = true


# ======================================================================= spoiler rules
static func _script_has(path: String, method: String) -> bool:
	if not ResourceLoader.exists(path):
		return false
	var sc: Script = load(path)
	for m in sc.get_script_method_list():
		if str(m["name"]) == method:
			return true
	return false


## May the player see this recipe in the guide? Uses SkillTree.recipe_visible(rid) when the merged
## game has it; otherwise a recipe behind an unset discovery flag stays hidden.
static func recipe_visible(rid: String) -> bool:
	var r := DB.recipe(rid)
	if r.is_empty() or bool(r.get("secret", false)) and not Game.has_flag("recipe_" + rid):
		return false
	if _script_has("res://scripts/systems/skilltree.gd", "recipe_visible"):
		return bool((load("res://scripts/systems/skilltree.gd") as Script).call("recipe_visible", rid))
	var rf := str(r.get("requires_flag", ""))
	return rf == "" or Game.has_flag(rf)


## Items: seen ones always; otherwise only items without a rare/secret tag whose recipe (if any) is visible.
static func item_visible(def_id: String) -> bool:
	if seen().has(def_id):
		return true
	var d := DB.item(def_id)
	if d.is_empty():
		return false
	for t in d.get("tags", []):
		if SECRET_TAGS.has(str(t)):
			return false
	for r in DB.recipes.values():
		if str(r.get("output", "")) == def_id and not recipe_visible(str(r["id"])):
			return false
	return true


# ======================================================================= entries
static func entries() -> Array:
	var out := []
	_basics(out)
	_recipes(out)
	_stations(out)
	_materials(out)
	_skilltree(out)
	_hirelings(out)
	_careers(out)
	_dice(out)
	_workshop(out)
	_ironfront(out)
	return out


static func tab_entries(tab: String) -> Array:
	return entries().filter(func(e): return e["tab"] == tab)


## Case-insensitive search over titles, bodies and keywords of every tab ("" returns everything).
static func search(q: String) -> Array:
	var qq := q.strip_edges().to_lower()
	if qq == "":
		return entries()
	var words := qq.split(" ", false)
	return entries().filter(func(e):
		var hay := (str(e["title"]) + " " + str(e["body"]) + " " + str(e.get("keys", ""))).to_lower()
		for w in words:
			if not hay.contains(w):
				return false
		return true)


static func tab_name(tab: String) -> String:
	for t in TABS:
		if t[0] == tab:
			return t[1]
	return tab


static func _e(out: Array, tab: String, title: String, body: String, icon := "", keys := "") -> void:
	out.append({"tab": tab, "title": title, "body": body, "icon": icon, "keys": keys})


static func _key(action: String) -> String:
	return Settings.key_label(action)


# ----------------------------------------------------------------------- basics
static func _basics(out: Array) -> void:
	_e(out, "basics", "Moving about", "Walk with [b]W A S D[/b] or the arrow keys; hold [b]%s[/b] to hurry. Roofs fade away when you step inside a building." % _key("run"), "ui/tb_map", "walk run movement keys")
	_e(out, "basics", "Interacting", "Walk up to a person, a workstation, a bed or a notice: its name appears at the bottom of the screen. Press [b]%s[/b] (or Space) to talk or use it." % _key("interact"), "ui/tb_help", "talk use interact")
	_e(out, "basics", "The toolbar and hotkeys", "The illustrated toolbar at the bottom opens every ledger. Hover a button to see its shortcut; a glowing button needs your attention.\n[b]I[/b] Inventory · [b]K[/b] Skills · [b]H[/b] Hirelings · [b]J[/b] Adventurers · [b]B[/b] Most Wanted · [b]O[/b] Orders · [b]L[/b] Ledger · [b]M[/b] Map · [b]F1[/b] Help · [b]Esc[/b] Menu.\nRight-click the Skills button for your skill levels, the Adventurers button for the Most Wanted board.", "ui/tb_inventory", "hotkeys shortcuts toolbar")
	_e(out, "basics", "Time", "A day lasts about fifteen minutes. [b]P[/b] pauses, [b]+[/b] and [b]−[/b] change the speed. Open ledgers stop the clock. Sleep in your bed to skip the night.", "", "clock pause speed sleep day")
	_e(out, "basics", "The minimap and the map", "The minimap in the top-right corner shows you (the arrow), buildings, roads, the stream and the people around. A speech mark means someone wants a word with you. Click it, or press [b]M[/b], for the full village map with names and exits.", "ui/tb_map", "minimap map markers")
	_e(out, "basics", "Saving", "Esc opens the menu where you can save. [b]F5[/b] quick-saves and [b]F9[/b] quick-loads.", "", "save load quicksave")
	_e(out, "basics", "Histories", "People, pieces of work and workstations remember. Use the [b]History[/b] buttons in conversations, the inventory and station headers to read what happened.", "", "history memory records")


# ----------------------------------------------------------------------- recipes
static func _recipes(out: Array) -> void:
	var rs := DB.recipes.values()
	rs.sort_custom(func(a, b): return int(a.get("difficulty", 0)) < int(b.get("difficulty", 0)))
	for r in rs:
		var rid := str(r["id"])
		if not recipe_visible(rid):
			continue
		var ins := []
		for k in r.get("inputs", {}):
			ins.append("%d× %s" % [int(r["inputs"][k]), DB.item(k).get("name", k)])
		var st := []
		for s in r.get("steps", []):
			st.append(DB.station(s).get("name", s))
		var req := ""
		for sk in r.get("requires", {}):
			req += "  Requires %s %d." % [SkillSys.skill_name(sk), int(r["requires"][sk])]
		var dice := []
		for k in r.get("dice", {}):
			dice.append("%s %s" % [str(k).capitalize(), str(r["dice"][k])])
		var out_def := str(r.get("output", ""))
		_e(out, "recipes", str(r.get("name", rid)),
			"[i]%s[/i]\n[b]Discipline:[/b] %s · [b]Difficulty:[/b] %d\n[b]Needs:[/b] %s\n[b]Stations:[/b] %s\n[b]Dice:[/b] %s%s" % [str(r.get("desc", "")),
				Crafting.DISCIPLINE_NAME.get(str(r.get("discipline", "")), str(r.get("discipline", ""))), int(r.get("difficulty", 0)),
				", ".join(ins), " → ".join(st), ", ".join(dice) if not dice.is_empty() else "none", ("\n" + req.strip_edges()) if req != "" else ""],
			"icons/" + str(DB.item(out_def).get("icon", out_def)), "recipe " + str(r.get("category", "")) + " " + ", ".join(ins))


# ----------------------------------------------------------------------- stations
static func _stations(out: Array) -> void:
	for st in DB.stations.values():
		var sid := str(st["id"])
		var c: Dictionary = st.get("check", {})
		var known := 0
		for r in Crafting.recipes_for_station(sid):
			if recipe_visible(str(r["id"])):
				known += 1
		_e(out, "stations", str(st.get("name", sid)),
			"%s\n[b]Discipline:[/b] %s · [b]Checks per step:[/b] %d · [b]Recipes you know that use it:[/b] %d\nYour %s level widens the precision zone and slows the needle." % [str(st.get("purpose", "")),
				Crafting.DISCIPLINE_NAME.get(str(st.get("discipline", "")), ""), int(c.get("count", 1)), known, SkillSys.skill_name(Crafting.skill_for_station(sid))],
			"stations/" + sid, "station workstation " + str(st.get("discipline", "")))


# ----------------------------------------------------------------------- materials
static func _materials(out: Array) -> void:
	for d in DB.items.values():
		var t := str(d.get("type", ""))
		if not t in ["material", "runestone", "potion"]:
			continue
		var id := str(d["id"])
		if not item_visible(id):
			continue
		var uses := []
		for r in DB.recipes.values():
			if (r.get("inputs", {}) as Dictionary).has(id) and recipe_visible(str(r["id"])):
				uses.append(str(r.get("name", r["id"])))
		_e(out, "materials", str(d.get("name", id)), "%s\n[b]Value:[/b] %d g%s" % [str(d.get("desc", "")), int(d.get("value", 0)),
			("\n[b]Used in:[/b] " + ", ".join(uses.slice(0, 6)) + ("…" if uses.size() > 6 else "")) if not uses.is_empty() else ""],
			"icons/" + str(d.get("icon", id)), "material " + t)


# ----------------------------------------------------------------------- rules sections
static func _skilltree(out: Array) -> void:
	for s in DB.skill_list:
		var sd: Dictionary = s if s is Dictionary else DB.skills.get(str(s), {})
		if sd.is_empty():
			continue
		_e(out, "skilltree", "%s (you: level %d)" % [str(sd.get("name", "")), Game.player_level(str(sd.get("id", "")))] if not Game.state.is_empty() else str(sd.get("name", "")),
			str(sd.get("desc", "")), "", "skill level xp")
	_e(out, "skilltree", "How skills grow", "Every check, finished piece, repair and expedition earns experience in the skill it uses. Experts learn little from routine work — take on harder recipes to keep growing.", "", "experience xp level")
	_e(out, "skilltree", "The skill tree", "Beyond plain levels, the smith's skill tree holds new techniques, stations and recipes. Points are earned as you level; each branch opens deeper nodes. Locked nodes tell you what they need. Open it from the toolbar.", "ui/tb_skilltree", "skill tree points unlock nodes branch")
	_e(out, "skilltree", "Recipes and stations unlocked", "Some recipes need a skill level, a skill-tree node or a discovery (a recipe scroll, a relic studied). A locked recipe or station always says why in its tooltip.", "", "unlock locked requires")


static func _hirelings(out: Array) -> void:
	_e(out, "hirelings", "Hiring", "Applicants gather at the forge; open Hirelings ([b]H[/b]) to read their skills, traits and wage, and hire with a signing fee. Wages are paid every morning.", "ui/tb_hirelings", "hire applicant wage fee")
	_e(out, "hirelings", "Work allocation", "Divide each hireling's day between work skills (mining, alchemy, runecraft, smithing…). They produce materials during work hours and grow in what they practise. A hireling at your side also assists your crafting.", "", "allocation work produce assist")
	_e(out, "hirelings", "Expeditions", "Send a hireling through a village exit to a region. The ledger shows the odds first; they return days later with a bag to open in the workshop — or hurt, or not at all.", "", "expedition send region odds bag")
	_e(out, "hirelings", "Potential and traits", "Traits change how fast someone learns and what they are good at. Potential reveals itself with time.", "", "trait potential")


static func _careers(out: Array) -> void:
	_e(out, "careers", "Adventurers", "Adventurers live in the village between expeditions. They buy what is on display, place commissions for gear they need and set out in parties at dawn. Your work decides how they fare.", "ui/tb_adventurers", "adventurer party expedition")
	_e(out, "careers", "Renown", "Deeds earn renown. Titles: " + ", ".join(DB.expeditions.get("renown_titles", []).map(func(t): return str(t[1]))) + ". The Most Wanted board ([b]B[/b]) ranks them.", "ui/tb_wanted", "renown title most wanted board")
	var arch: Dictionary = DB.expeditions.get("archetypes", {})
	for cls in arch:
		var a: Dictionary = arch[cls]
		_e(out, "careers", str(cls), "[b]Role:[/b] %s · [b]Prefers:[/b] %s · [b]Skills:[/b] %s" % [str(a.get("role", "")), ", ".join(a.get("prefers", [])), ", ".join(a.get("skills", []))],
			"", "class career " + str(a.get("role", "")))
	_e(out, "careers", "Death, injury and disputes", "Bad gear fails at the worst moment. The injured rest at the inn; the unlucky do not come home. A customer whose gear failed may come back to dispute it — refunding costs coin, refusing costs reputation.", "", "death injury dispute refund")


static func _dice(out: Array) -> void:
	_e(out, "dice", "Precision checks", "Each recipe step is played at a station: a needle sweeps a ring and you press [b]E[/b] inside the gilt zone. The centre is best. Craftsmanship is the weighted mean of every check plus your skill bonus.", "ui/tb_designer", "check needle ring quality craftsmanship")
	var dice: Dictionary = DB.crafting.get("dice", {})
	var lines := []
	for k in dice:
		lines.append("[b]%s[/b] — %s" % [str(dice[k].get("label", k)), str(dice[k].get("desc", ""))])
	_e(out, "dice", "The dice", "After the last step you roll the recipe's dice (digitally or with your own). " + "\n".join(lines), "ui/dice_d20", "dice roll d20 d100 physical")
	var rar: Dictionary = DB.crafting.get("rarity", {})
	var th: Dictionary = rar.get("thresholds", {})
	_e(out, "dice", "Rarity", "Craftsmanship and the fortune die combine into a rarity score: Magic from %s, Rare from %s, Legendary from %s. Runestones, fine materials and masterwork (%s%% craftsmanship) add to it. Common · Magic · Rare · Legendary." % [
		str(th.get("magic", "?")), str(th.get("rare", "?")), str(th.get("legendary", "?")), str(rar.get("masterwork", {}).get("quality", "?"))], "icons/star", "rarity common magic rare legendary masterwork")


static func _workshop(out: Array) -> void:
	_e(out, "workshop", "Owning the workshop", "The Ironhand forge is a building of rooms. You begin with part of it; the rest can be bought room by room from the Workshop ledger. A station only works when it is installed in a room you own.", "ui/tb_property", "property rooms buy own")
	_e(out, "workshop", "Editing and furnishing", "From the Workshop ledger you can place, move and store stations and furniture inside owned rooms. Keep paths clear: you and your hirelings need to walk between stations.", "", "edit furnish place move station")
	_e(out, "workshop", "Upgrades", "The Ledger's Upgrades tab sells improvements — display cases, better tools, the Arcane Foundry — some needing a skill level or a rare find.", "ui/tb_ledger", "upgrade foundry display")


static func _ironfront(out: Array) -> void:
	_e(out, "ironfront", "What Ironfront is", "Ironfront is a card game of shields and siege played at Barnaby's table in the basement. Bring coin to buy in.", "", "ironfront card game barnaby")
	_e(out, "ironfront", "How a round goes", "Each player builds a front line from their hand. Cards have strength and a trait; the stronger line wins the lane, and the most lanes win the round. Read every card's text — traits break ties and turn losing lanes.", "", "round lane strength trait")
	_e(out, "ironfront", "Stakes and etiquette", "Stakes are agreed before the deal. Barnaby keeps the house honest; regulars remember how you win and how you lose.", "", "stakes bet")
	var data: Variant = DB.extra("ironfront")
	if data is Dictionary and (data as Dictionary).has("rules"):
		var rules: Variant = data["rules"]
		if rules is Array:
			for r in rules:
				if r is Dictionary:
					_e(out, "ironfront", str(r.get("title", "Rule")), str(r.get("text", "")), "", "rule")
