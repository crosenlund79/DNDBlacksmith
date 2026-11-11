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
	["knowledge", "Knowledge & Notes"],
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
		if not bool(it.get("dev", false)):   # developer-tool spawns teach nothing
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
## Built once per moment of play: typing in the search box re-reads the cache (the clock stands still while Help is open).
static var _cache_key := ""
static var _cache: Array = []


static func _key_now() -> String:
	if Game.state.is_empty():
		return "menu"
	return "%d|%d|%d|%d|%d|%d|%d" % [Game.now(), Game.gold(), Game.inventory().size(), (Game.state.get("flags", {}) as Dictionary).hash(),
		SkillTree.learned().hash(), (Game.state.get("knowledge", {}).get("bought", {}) as Dictionary).size(), seen().size()]


static func entries() -> Array:
	var key := _key_now()
	if key != _cache_key or _cache.is_empty():
		_cache = _build_entries()
		_cache_key = key
	return _cache


static func _build_entries() -> Array:
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
	_knowledge(out)
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


static func _e(out: Array, tab: String, title: String, body: String, icon := "", keys := "", topic := "") -> void:
	out.append({"tab": tab, "title": title, "body": body, "icon": icon, "keys": keys, "topic": topic})


## Is an encyclopedia page (item:<def> | recipe:<id> | station:<id> | knowledge) open to the player?
## Recipes and items follow the spoiler rules; stations are public furniture.
static func topic_visible(topic: String) -> bool:
	if topic == "knowledge":
		return true
	if topic.begins_with("item:"):
		return not DB.item(topic.substr(5)).is_empty() and item_visible(topic.substr(5))
	if topic.begins_with("recipe:"):
		return recipe_visible(topic.substr(7))
	if topic.begins_with("station:"):
		return not DB.station(topic.substr(8)).is_empty()
	return false


static func _key(action: String) -> String:
	return Settings.key_label(action)


# ----------------------------------------------------------------------- basics
static func _basics(out: Array) -> void:
	_e(out, "basics", "Moving about", "Walk with [b]W A S D[/b] or the arrow keys; hold [b]%s[/b] to hurry. Roofs fade away when you step inside a building." % _key("run"), "ui/tb_map", "walk run movement keys")
	_e(out, "basics", "Interacting", "Walk up to a person, a workstation, a bed or a notice: its name appears at the bottom of the screen. Press [b]%s[/b] (or Space) to talk or use it." % _key("interact"), "ui/tb_help", "talk use interact")
	# S2: the list comes from Settings.HOTKEY_HELP and the real bindings, so it cannot drift from them
	_e(out, "basics", "The toolbar and hotkeys", ("The illustrated toolbar at the bottom opens every ledger. Each button's key is on its lower right; a smaller key on its upper left opens what a right-click opens (the Skill Tree's [b]%s[/b] for your skill levels, the Workshop's [b]%s[/b] for the Workshop Ledger). Hover a button for its name; a glowing button needs your attention.\n%s.\nLeft-click the ground, an object or a person to walk there (Settings can turn this off).") % [_key("panel_skill_levels"), _key("panel_workshop"), Settings.controls_text()], "ui/tb_inventory", "hotkeys shortcuts toolbar keys controls skill tree skills levels workshop ledger")
	_e(out, "basics", "Walking to the next station", "Settings › [b]Auto-walk to the next station[/b] (off unless you turn it on): when a skill check finishes a step whose recipe continues at another station, the smith walks there by himself. It only walks — it opens nothing, starts no work and never chooses a recipe; press [b]%s[/b] at the station to carry on. Without it, the station's [b]Walk to …[/b] button takes you there (and opens the station) when you ask." % _key("interact"), "ui/tb_map", "auto walk next station automatic walking setting")
	_e(out, "basics", "Time", "A day lasts about fifteen minutes. [b]P[/b] pauses, [b]+[/b] and [b]−[/b] change the speed. Open ledgers stop the clock. Sleep in your bed to skip the night.", "", "clock pause speed sleep day")
	_e(out, "basics", "The minimap and the map", "The minimap in the top-right corner shows you (the arrow), buildings, roads, the stream and the people around. A speech mark means someone wants a word with you. Click it, or press [b]M[/b], for the full village map with names and exits.", "ui/tb_map", "minimap map markers")
	_e(out, "basics", "Steward Mode", "Hand the running forge to your steward with the toolbar's signpost, [b]%s[/b] or the Workshop Ledger. While you are away the steward runs the routine business through the same actions you would take — ordinary commissions for your apprentices, materials at the open village counters, the display and waiting customers — within your [b]standing instructions[/b] (spending limits, purchases, duties, protected pieces, reserved supplies, order and selling rules). It never crafts (you gain no crafting experience while away) and leaves consequential matters for you; the genuinely significant ones arrive as [b]sealed letters[/b]. Time keeps running while you look around; you cannot act in the world until you take the workshop back, which shows [b]While You Were Away[/b]. It works only while the game runs: nothing happens while the game is closed, and a loaded save finds you back at the forge." % _key("panel_steward"), "ui/act_road", "steward away manage automatic letters sealed report")
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
			"%s[b]Discipline:[/b] %s · [b]Difficulty:[/b] %d\n[b]Needs:[/b] %s\n[b]Stations:[/b] %s\n[b]Dice:[/b] %s%s" % [("[i]%s[/i]\n" % str(r["desc"])) if str(r.get("desc", "")) != "" else "",
				Crafting.DISCIPLINE_NAME.get(str(r.get("discipline", "")), str(r.get("discipline", ""))), int(r.get("difficulty", 0)),
				", ".join(ins), " → ".join(st), ", ".join(dice) if not dice.is_empty() else "none", ("\n" + req.strip_edges()) if req != "" else ""],
			"icons/" + str(DB.item(out_def).get("icon", out_def)), "recipe " + str(r.get("category", "")) + " " + ", ".join(ins), "recipe:" + rid)


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
			"stations/" + sid, "station workstation " + str(st.get("discipline", "")), "station:" + sid)


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
		var get_it := Guide.tooltip_line(id) if not Game.state.is_empty() else ""
		_e(out, "materials", str(d.get("name", id)), "%s%s[b]Value:[/b] %d g%s" % [(str(d.get("desc", "")) + "\n") if str(d.get("desc", "")) != "" else "",
			("[b]Get it:[/b] %s · " % get_it) if get_it != "" else "", int(d.get("value", 0)),
			("\n[b]Used in:[/b] " + ", ".join(uses.slice(0, 6)) + ("…" if uses.size() > 6 else "")) if not uses.is_empty() else ""],
			"icons/" + str(d.get("icon", id)), "material " + t, "item:" + id)


# ----------------------------------------------------------------------- rules sections
static func _skilltree(out: Array) -> void:
	for s in DB.skill_list:
		var sd: Dictionary = s if s is Dictionary else DB.skills.get(str(s), {})
		if sd.is_empty():
			continue
		var sid := str(sd.get("id", ""))
		var basic := not Game.state.is_empty() and Workers.is_basic("player", sid)
		_e(out, "skilltree", ("%s (you: level %d%s)" % [str(sd.get("name", "")), Game.player_level(sid), " — basic" if basic else ""]) if not Game.state.is_empty() else str(sd.get("name", "")),
			str(sd.get("desc", "")) + ((" The smith's %s grows to level %d; mastery belongs to %s." % [str(sd.get("name", "")).to_lower(), Workers.BASIC_LEVEL,
			Workers.a_noun(Workers.skill_profession(sid))]) if basic else ""), "", "skill level xp")
	_e(out, "skilltree", "Professions and competence", ("Everyone in the workshop has a profession — blacksmith, leatherworker & tailor, runesmith, alchemist & herbalist (herb lore belongs to the alchemist) or arcanist — and works at their OWN level: a check's zone and pace, the quality of their work, the stations they may use and the work they may take all follow the person at the station, not the smith. "
		+ "The smith is the blacksmith: smithing and mining grow without limit; his other crafts grow to level %d (levels he earned before are kept). Basic work in another craft stays open to him at his own level; master-grade work (a Design whose difficulty asks more than level %d) needs a specialist of that craft — locked Designs say who. "
		+ "What the workshop KNOWS (the Designs and stations it has learned in the skill tree) is separate from anyone's competence: a specialist can only make a Design the workshop knows, and a node in another craft's branch can be met by a specialist on the staff. Field hirelings keep their own trade (mining, trading, relic hunting) and do not work the stations.") % [Workers.BASIC_LEVEL, Workers.BASIC_LEVEL],
		"", "profession specialist competence basic runesmith alchemist arcanist leatherworker blacksmith eligible who can")
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
	_e(out, "careers", "Equipment slots", "Every adventurer and hireling wears gear by body region: head (helmet or hood), neck (amulet), shoulders (cloak), torso (armour), hands (gloves), main hand (weapon), off hand (shield), waist (belt), finger (ring) and feet (boots), with a companion creature at their side. A cloak and an amulet are worn together. Their character sheet shows the figure; hover a piece for the item, click it for its maker and story.", "ui/stat_gear", "equipment slot cloak amulet helmet ring gear sheet")
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
	_e(out, "dice", "The dice", "After the last step you roll the recipe's dice (digitally or with your own).\n" + "\n".join(lines), "ui/dice_d20", "dice roll d20 d100 physical")
	var rar: Dictionary = DB.crafting.get("rarity", {})
	var th: Dictionary = rar.get("thresholds", {})
	_e(out, "dice", "Rarity", "Craftsmanship and the fortune die combine into a rarity score: Magic from %s, Rare from %s, Legendary from %s. Runestones, fine materials and masterwork (%s%% craftsmanship) add to it. Common · Magic · Rare · Legendary." % [
		str(th.get("magic", "?")), str(th.get("rare", "?")), str(th.get("legendary", "?")), str(rar.get("masterwork", {}).get("quality", "?"))], "icons/star", "rarity common magic rare legendary masterwork")


static func _workshop(out: Array) -> void:
	_e(out, "workshop", "Owning the workshop", "The Ironhand forge is a building of rooms. You begin with part of it; the rest can be bought room by room from the toolbar's [b]Workshop[/b] ([b]%s[/b]: Property & Workshop). A station only works when it is installed in a room you own." % _key("panel_property"), "ui/tb_property", "property rooms buy own workshop")
	_e(out, "workshop", "Editing and furnishing", "From the Workshop ([b]%s[/b]) you can place, move and store stations and furniture inside owned rooms. Keep paths clear: you and your hirelings need to walk between stations." % _key("panel_property"), "", "edit furnish place move station")
	_e(out, "workshop", "Apprentices", "Once you can teach (Smithing 6, or your first room bought next door) would-be apprentices pin their names to the notice board's [b]Workshop apprentices[/b] tab each week. They work inside the smithy from 8:00 to 18:00 (break at noon) on the queue in the Workshop Ledger ([b]" + _key("panel_workshop") + "[/b], or right-click the Workshop button): customer repairs, commissions, crafting, preparing materials and station upkeep — at real stations, from real materials in your stores. You always have priority at a station; they step aside. Talk to them in the smithy to teach them for an hour, hear how the work goes, or answer when they ask to open a workshop of their own. Their pieces carry their own mark.", "ui/tb_hirelings", "apprentice workshop queue ledger teach mentor mark")
	_e(out, "workshop", "Major contracts & the Project Bench", "Now and then a patron — a wealthy merchant, the village muster, the Highmarsh Watch, the Merchants' Guild, a lord of the Marches, in time even the Royal Household — sends a sealed letter with a large order. Letters come only when your work has earned them (pieces forged, a good name, earlier orders delivered well, famous work in the Hall of Fame, a renowned forge) and each says why it came. Accepting pays an advance and brings the patron's crate of ordinary materials, which the order uses before your own stores. Large orders are worked at the [b]Project Bench[/b] (buy it under Property & Workshop › Equipment and set it up in a workshop room) in blocks of 1, 2 or 4 hours: time passes, you tire, and your skill sets the pace and the craftsmanship. Apprentices put hours in through the Workshop ledger (task «Contract hours»). Rare materials the patron cannot supply are listed with the Guide's way to get them — a shop, a ship's import, a trade run or an expedition — and are needed from the middle of the order on. Some orders ask for one masterpiece: forge it yourself at the stations and lay it into the order at the bench. Deliver on time and above the minimum for full pay, reputation and the patron's favour; late or poor work pays less and costs reputation, and a long-overdue order is withdrawn.", "contracts/crate_goods", "contract patron order bench hours masterpiece royal guild watch letter")
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


# ----------------------------------------------------------------------- knowledge bought
static func _knowledge(out: Array) -> void:
	_e(out, "knowledge", "Who sells knowledge", "Most things are free to learn: every page here says where an item comes from and what to do next. A few villagers sell what they alone know — [b]Silas Quell[/b] at the pawnshop (old notes), the [b]harbourmaster[/b] (lore and cargo from the far ports) and [b]Maud Fennimore[/b] the herbalist (herb lore). A hint tells you where and how; the discovery is still yours to make.", "ui/guide_knowledge", "knowledge hint buy notes lore secret", "knowledge")
	if Game.state.is_empty():
		return
	for k in Knowledge.owned_list():
		_e(out, "knowledge", str(k["title"]), "%s\n[color=#5e421c][i]Bought from %s on day %d (%s).[/i][/color]" % [str(k["text"]), str(k["seller_name"]), int(k["day"]),
			"a hint" if str(k["kind"]) == "hint" else "complete knowledge"], "ui/guide_knowledge", "knowledge hint " + str(k["kind"]), "knowledge")
