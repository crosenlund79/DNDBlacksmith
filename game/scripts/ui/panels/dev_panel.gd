## DevPanel — developer testing tools (F10). Not part of normal play: it never appears in menus and
## is only opened with its own key. Accelerates time, hands out representative materials and test
## items, and pokes the simulation so every system can be exercised quickly during playtesting.
## S2: every tool is locked until "Enable cheats for this session" (DevTools: a session switch, never saved, off after a
## new game or a load; a "CHEATS ON" banner shows while it is on). The bar also holds the optional skill-check bypass;
## "Test scenarios" open a crafting, workshop, counter-commission or Project Bench situation with the game's own setters.
## DA: Udviklerværktøj (F10) til test: tid, materialer, testgenstande og udløsning af hændelser.
class_name DevPanel
extends UIWindow

const KITS := {
	"Smithing kit": [["ore_iron", 10], ["coal", 12], ["ingot_iron", 8], ["ingot_steel", 6], ["leather_cured", 6]],
	"Runecraft kit": [["runestone_blank", 6], ["reagent_salt", 6], ["herb_emberleaf", 6], ["runestone_ember", 2], ["runestone_ward", 2]],
	"Alchemy kit": [["herb_moonwort", 10], ["herb_emberleaf", 10], ["reagent_salt", 8], ["coal", 4], ["coating_flame", 2], ["coating_frost", 1], ["oil_whetstone", 2]],
	"Stitching kit": [["leather_hide", 8], ["leather_cured", 8], ["thread_linen", 8], ["thread_ethereal", 4]],
	"Gems & rare minerals": [["gem_garnet", 3], ["gem_sapphire", 3], ["gem_moonstone", 3], ["gem_starstone", 1], ["starmetal_fragment", 2], ["ore_silver", 8]],
	"Arcane kit": [["ore_mithril", 6], ["ore_adamantine", 6], ["gem_moonstone", 3], ["coal", 8]],
	"Relics to study": [["relic_unknown_arms", 1], ["relic_unknown_tablet", 1], ["relic_unknown_reliquary", 1], ["recipe_scroll", 1]],
}

var body: VBoxContainer
var out: RichTextLabel
var cheat_state: RichTextLabel
var cheat_btn: Button
var bypass_btn: Button
var skill_labels := {}


func _init() -> void:
	super._init("Developer Tools — testing only (F10)", 1500, 860, true)
	name = "DevPanel"


func _ready() -> void:
	super._ready()
	out = UIKit.rich("", 19, true)
	content.add_child(_cheat_bar())
	body = UIKit.vbox(8)
	_scenarios()
	# UX iteration: the developer catalogue — every item, spawned with quantity / rarity / craftsmanship, and money
	var cat := UIKit.vbox(4)
	var cb := UIKit.button("Open the developer catalogue (every item, money)", func():
		close()
		Events.open_panel.emit.call_deferred("dev_catalogue", {}), 0)
	cb.name = "OpenCatalogue"
	cat.add_child(cb)
	cat.add_child(UIKit.rich("[i][color=#c8b898]Spawned things are marked as developer items and never count for fame or knowledge.[/color][/i]", 17, true))
	body.add_child(cat)
	_section("Time", [
		["+1 hour", func(): _adv(60)], ["+6 hours", func(): _adv(360)], ["+1 day", func(): _adv(1440)], ["+7 days", func(): _adv(1440 * 7)],
		["Skip to 7:00 (departures)", func(): Game.skip_to_hour(7); _say("Morning.")],
		["Skip to 19:00 (inn evening)", func(): Game.skip_to_hour(19); _say("Evening.")]])
	_section("Purse & skills", [
		["+1000 gold", func(): DevTools.add_money(1000); _say("+1000 g")],
		["+2 levels in every craft", func(): _skills()],
		["Unlock every workshop upgrade", func(): _upgrades()]])
	var kit_btns := []
	for k in KITS:
		var kk: String = k
		kit_btns.append([k, func(): _kit(kk)])
	_section("Materials", kit_btns)
	_section("Test items", [
		["Legendary steel sword", func(): _legend()],
		["Emberwarden (enchanted)", func(): _item("sword_emberwarden", 104.0)],
		["Adamantine Warplate", func(): _item("warplate_adamantine", 100.0)],
		["Silver band (to propose)", func(): _item("ring_silver", 95.0)],
		["Healing draughts ×5 on the shelf", func(): _potions()]])
	_section("World", [
		["Adventurers: resolve every expedition now", func(): _resolve_all()],
		["Send in-town adventurers out", func(): _depart_all()],
		["Hirelings: finish expeditions now", func(): _hire_home()],
		["A customer sets out", func(): Shop._add_customer(Adv.in_town().pick_random()["id"] if not Adv.in_town().is_empty() else "martha", "browse"); _say("A customer is on the way.")],
		["A dispute", func(): _dispute()],
		["Village social events", func(): Sim._social_events(); _say("Social events rolled.")],
		["Weekly grocer delivery", func(): Game.state["world"]["delivery_pending"] = true; Events.world_flag_changed.emit("delivery"); _say("Aldric is at the door.")],
		["Reveal all adventurers (rumours)", func(): _rumours()]])
	_section("Expeditions & difficulty", [
		["Form, provision & dispatch parties now", func(): _dispatch()],
		["Step every expedition once", func(): _step_all(1)],
		["Run every expedition to its end", func(): _step_all(400)],
		["Apprentice", func(): Expeditions.set_difficulty("apprentice"); _say("Difficulty: Apprentice")],
		["Journeyman", func(): Expeditions.set_difficulty("journeyman"); _say("Difficulty: Journeyman")],
		["Master", func(): Expeditions.set_difficulty("master"); _say("Difficulty: Master")],
		["Pause / resume time", func(): Game.toggle_pause(); _say("Paused" if Game.paused else "Running")],
		["Speed ×1", func(): Game.set_speed(1); _say("×1")], ["Speed ×4", func(): Game.set_speed(4); _say("×4")], ["Speed ×8", func(): Game.set_speed(8); _say("×8")],
		["Open the Most Wanted board", func(): Events.open_panel.emit("wanted", {})]])
	_iter9_tools()
	_section("Relationships", [
		["+20 affection: everyone in town", func(): _aff(20.0)],
		["−20 affection: everyone in town", func(): _aff(-20.0)]])
	content.add_child(UIKit.scroll(body, 560))
	content.add_child(out)
	_lock()


# ------------------------------------------------------------------ S2: the cheat switch, the bypass and scenarios
## The bar above every tool: cheats are OFF until switched on here, for this session only (DevTools).
func _cheat_bar() -> Control:
	var bar := UIKit.hbox(12)
	bar.name = "CheatBar"
	cheat_state = UIKit.rich("", 20, true)
	cheat_state.custom_minimum_size = Vector2(620, 0)
	bar.add_child(cheat_state)
	cheat_btn = UIKit.button("", func():
		DevTools.set_enabled(not DevTools.enabled())
		_lock()
		_say("Cheats on" if DevTools.enabled() else "Cheats off"), 300)
	cheat_btn.name = "CheatToggle"
	bar.add_child(cheat_btn)
	bypass_btn = UIKit.button("", func():
		DevTools.set_bypass(not DevTools.bypass_checks())
		_lock()
		_say("Skill checks bypassed (%d%%)" % int(DevTools.BYPASS_QUALITY) if DevTools.bypass_checks() else "Skill checks played normally"), 300)
	bypass_btn.name = "BypassToggle"
	bar.add_child(bypass_btn)
	return bar


## Every tool below the bar works only while cheats are on; the bar says which state the session is in.
func _lock() -> void:
	var on := DevTools.enabled()
	cheat_state.text = ("[color=#ff9a7a][b]CHEATS ON[/b][/color] for this session · a save made now is marked as tested with cheats" if on
		else "[color=#c8b898][b]Cheats are OFF[/b] · switch them on to use these tools (this session only, never saved)[/color]")
	cheat_btn.text = "Switch cheats off" if on else "Enable cheats for this session"
	bypass_btn.text = ("Skill-check bypass: ON" if DevTools.bypass_checks() else "Skill-check bypass: off")
	bypass_btn.disabled = not on
	_lock_tree(body, on)
	_skill_text()


func _lock_tree(n: Node, on: bool) -> void:
	for c in n.get_children():
		if c is BaseButton:
			(c as BaseButton).disabled = not on
		elif c is LineEdit:
			(c as LineEdit).editable = on
		elif c is SpinBox:
			(c as SpinBox).editable = on
		_lock_tree(c, on)


## Fast ways into the situations worth testing, built from the game's own setters.
func _scenarios() -> void:
	_section("Test scenarios", [
		["Crafting: materials, then the forge", func(): _scenario_craft()],
		["Workshop: hire an apprentice and fill the queue", func(): _scenario_workshop()],
		["Commission request at the counter", func(): _scenario_counter()],
		["Contract at the Project Bench", func(): _scenario_contract()]])


func _scenario_craft() -> void:
	var rid := "iron_longsword"
	var r := DB.recipe(rid)
	if r.is_empty() or not DevTools.enabled():
		return
	for d in r.get("inputs", {}):
		var have := Game.count(str(d))
		var need := int(r["inputs"][d]) * 2
		if have < need:
			DevTools.spawn(str(d), need - have)
	var sid := str((r.get("steps", ["forge"]) as Array)[0])
	_say("Materials for two %ss; the %s is open." % [str(r.get("name", rid)), str(DB.station(sid).get("name", sid))])
	close()
	Events.open_panel.emit.call_deferred("station", {"id": sid})


func _scenario_workshop() -> void:
	var msgs := [ApprenticeDev.unlock()]
	if Apprentices.staff().is_empty():
		msgs.append(ApprenticeDev.hire_one())
	msgs.append(ApprenticeDev.give_materials())
	_say(" ".join(PackedStringArray(msgs)))
	close()
	Events.open_panel.emit.call_deferred("workshop", {})


## The richest adventurer in town sits down at the counter with a request — several things, some commissions.
func _scenario_counter() -> void:
	var best := {}
	for a in Adv.in_town():
		if Shop.customer(str(a["id"])).is_empty() and (best.is_empty() or int(a["gold"]) > int(best["gold"])):
			best = a
	if best.is_empty():
		_say("Nobody is in town to come to the counter.")
		return
	if Shop.free_seat() < 0:
		var first: Dictionary = Shop.customers()[0]
		Shop.remove_customer(str(first["npc"]))
	Shop._add_customer(str(best["id"]), "multi")
	Shop.mark_arrived(str(best["id"]), false)
	_say("%s is at the counter." % best["name"])
	close()
	Events.open_panel.emit.call_deferred("shop", {"tab": "customers", "npc": str(best["id"])})


## A patron's contract accepted, its crate at the bench (the bench is set up first when the workshop lacks one).
func _scenario_contract() -> void:
	var rebuilt := false
	if not Contracts.bench_installed():
		if not Property.owns("cobbler"):
			Property.dev_grant_unit("cobbler")
		if not Property.is_owned_station(Contracts.BENCH):
			(Property.st()["stored"] as Array).append(Contracts.BENCH)
		var plan := Property.plan_copy()
		var why := Property.auto_place(plan, Contracts.BENCH)
		if why != "" or Property.commit(plan) != "":
			_say("The Project Bench could not be placed: %s" % why)
			return
		rebuilt = true
	var o := Contracts.make_offer("drovers_kit")
	if o.has("error"):
		_say(str(o["error"]))
		return
	var err := Contracts.accept(str(o["id"]))
	_say(err if err != "" else "Contract accepted: %s." % str(o.get("title", "")))
	close()
	var main := get_tree().root.get_node_or_null("Main")
	if rebuilt and main and main.has_method("rebuild_world"):
		main.call_deferred("rebuild_world")
	Events.open_panel.emit.call_deferred("contracts", {"id": str(o["id"])})


func _skill_text() -> void:
	for id in skill_labels:
		var pair: Array = skill_labels[id]
		var l := pair[0] as Label
		if is_instance_valid(l):
			l.text = "%s %d" % [str(pair[1]), Game.player_level(str(id))]


func _section(title: String, btns: Array) -> void:
	body.add_child(UIKit.label(title, 24, "heading", UIKit.GILT))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	for b in btns:
		flow.add_child(UIKit.button(b[0], b[1], 0))
	body.add_child(flow)


func _say(t: String) -> void:
	out.text = "[color=#c8b898]%s — day %d, %02d:%02d, %d g[/color]" % [t, Game.day(), Game.hour(), int(Game.state["minute"]) % 60, Game.gold()]
	_skill_text()


func _adv(mins: int) -> void:
	Game.advance_minutes(mins)
	_say("Time passes")


func _skills() -> void:
	for sk in ["smithing", "runecraft", "alchemy", "arcane_metalwork", "enchanted_stitching"]:
		for i in 2:
			Game.grant_player_xp(sk, SkillSys.xp_needed(Game.player_level(sk) + 1))
	_say("Crafts improved")


func _upgrades() -> void:
	for u in DB.upgrades:
		if not Game.has_upgrade(u):
			Game.state["upgrades"].append(u)
	Game.set_flag("found_mithril")
	Events.world_flag_changed.emit("upgrades")
	_say("All upgrades installed")


func _kit(k: String) -> void:
	for pair in KITS[k]:
		var kit_item := Items.make(pair[0], {"qty": int(pair[1])})
		kit_item["dev"] = true
		Game.add_item(kit_item, false)
	Events.inventory_changed.emit()
	_say(k + " added")


func _item(def_id: String, q: float) -> void:
	DevTools.spawn(def_id, 1, "", q)
	_say(DB.item(def_id)["name"] + " added")


func _legend() -> void:
	var it := Loot.random_equipment("legendary_demo")
	it["dev"] = true
	Game.add_item(it, false)
	Events.legendary_found.emit(it)
	_say("Legendary added")


func _potions() -> void:
	var p := Items.make("potion_healing", {"qty": 5, "quality": 90.0})
	p["for_sale"] = true
	p["dev"] = true
	Game.inventory().append(p)
	Events.inventory_changed.emit()
	_say("Draughts on the shelf")


# ------------------------------------------------------------------ iteration 009 tools
## Calls a static function on a system script if it exists (systems are added by separate modules).
func _static_call(path: String, method: String, args := []) -> Variant:
	if not ResourceLoader.exists(path):
		_say("%s not available" % path.get_file())
		return null
	var sc: Script = load(path)
	for m in sc.get_script_method_list():
		if m["name"] == method:
			return sc.callv(method, args)
	_say("%s.%s() not available" % [path.get_file(), method])
	return null


func _iter9_tools() -> void:
	# money and any registered item
	body.add_child(UIKit.label("Items & money", 24, "heading", UIKit.GILT))
	var row := UIKit.hbox(8)
	var gold := LineEdit.new()
	gold.placeholder_text = "gold (e.g. 5000 or -200)"
	gold.custom_minimum_size = Vector2(240, 0)
	row.add_child(gold)
	row.add_child(UIKit.button("Grant gold", func(): DevTools.add_money(int(gold.text)); _say("%+d g" % int(gold.text)), 0))
	var find := LineEdit.new()
	find.placeholder_text = "item id or name…"
	find.custom_minimum_size = Vector2(280, 0)
	row.add_child(find)
	var qty := SpinBox.new()
	qty.min_value = 1
	qty.max_value = 99
	qty.value = 5
	row.add_child(qty)
	body.add_child(row)
	var matches := HFlowContainer.new()
	matches.add_theme_constant_override("h_separation", 6)
	body.add_child(matches)
	find.text_changed.connect(func(t: String):
		UIKit.clear(matches)
		if t.length() < 2:
			return
		var n := 0
		for it in DB.items.values():
			if n >= 24:
				break
			var q := t.to_lower()
			if str(it["id"]).contains(q) or str(it["name"]).to_lower().contains(q):
				var def: String = it["id"]
				var b := UIKit.button(str(it["name"]), func():
					DevTools.spawn(def, int(qty.value), "", 90.0)
					_say("%s ×%d added" % [DB.item(def)["name"], int(qty.value)]), 0)
				b.add_theme_font_size_override("font_size", 16)
				matches.add_child(b)
				n += 1)
	# skills
	body.add_child(UIKit.label("Skills & experience", 24, "heading", UIKit.GILT))
	var sk_flow := HFlowContainer.new()
	sk_flow.add_theme_constant_override("h_separation", 8)
	for sk in DB.skill_list:
		var id: String = sk["id"]
		var box := UIKit.hbox(2)
		var sl := UIKit.label("%s" % sk.get("name", id), 16, "body_bold", UIKit.PAPER)
		skill_labels[id] = [sl, str(sk.get("name", id))]   # S2: the current level beside each skill
		box.add_child(sl)
		box.add_child(UIKit.button("−", func(): _set_level(id, Game.player_level(id) - 1), 0))
		box.add_child(UIKit.button("+", func(): _set_level(id, Game.player_level(id) + 1), 0))
		box.add_child(UIKit.button("+XP", func(): Game.grant_player_xp(id, int(SkillSys.xp_needed(Game.player_level(id) + 1) / 2)); _skill_text(); _say("%s %d" % [id, Game.player_level(id)]), 0))
		sk_flow.add_child(box)
	body.add_child(sk_flow)
	# progression, property and workstations
	var unit_btns := []
	for u in Property.units():
		var uid: String = u["id"]
		if uid != "start":
			unit_btns.append(["Own: " + str(u["name"]), func(): Property.dev_grant_unit(uid); _rebuild("Owns " + str(u["name"]))])
	_section("Property & workstations (rebuilds the world)", unit_btns + [
		["Own the whole building", func(): for u2 in Property.units(): Property.dev_grant_unit(str(u2["id"])); _rebuild("Whole building owned")],
		["Install every station", func(): Property.dev_grant_all(); _rebuild("Every station installed")],
		["Buy every station (to storage)", func(): _buy_all_stations()],
		["Open Property & Workshop", func(): Events.open_panel.emit("property", {})]])
	_section("Skill tree & recipes", [
		["Unlock every skill-tree node", func(): _static_call("res://scripts/systems/skilltree.gd", "unlock_all"); Events.world_flag_changed.emit("tree"); _say("Every node unlocked")],
		["Reset the tree to a new game", func(): _static_call("res://scripts/systems/skilltree.gd", "reset_new"); _say("Tree reset")],
		["Learn every secret recipe", func(): _secret_recipes()],
		["Open the skill tree", func(): Events.open_panel.emit("skilltree", {})],
		["Open the equipment designer", func(): Events.open_panel.emit("designer", {})]])
	_section("Iteration 010 — village life", [
		["Caravan arrives now", func(): Commerce.dev_force_caravan(); _say("The caravan is in")],
		["Caravan leaves", func(): Commerce.dev_caravan_leave(); _say("The caravan left")],
		["Next hireling expedition: death", func(): Hire.force_outcome = "death"; _say("The next hireling expedition will end in death")],
		["Next hireling expedition: injury", func(): Hire.force_outcome = "injury"; _say("The next hireling expedition will end in injury")],
		["A ghost visits tonight", func(): Memorial.force_ghost = true; _say("A ghost will visit (needs a grave)")],
		["Every adventurer evaluates gear now", func(): Adv.gear_hour(); _say("Gear errands run")],
		["Epic: the first smith-made weapon on an adventurer", func(): _dev_epic()],
		["Open the Hall of Fame", func(): Events.open_panel.emit("hall_of_fame", {"id": "smithy"})],
		["Open quick travel", func(): Events.open_panel.emit("quick_travel", {})],
		["Ironfront: replay the invitation", func(): Ironfront.invite_new(); _say("Barnaby's invitation is back")]])
	_section("Iteration 011 — the world remembers", [
		["Open the world map", func(): Events.open_panel.emit("world_map", {})],
		["A stranger brings an old Ironhand blade", func(): _say("A stranger is on the way" if not ItemStory.stranger_visit().is_empty() else "No lost blade circulates yet (or no free seat)")],
		["Wake the first smith-made adventurer weapon", func(): _dev_awaken()]])
	_section("Iteration 012 — workshop", [
		["Unlock apprentices", func(): _say(ApprenticeDev.unlock())],
		["Add an applicant", func(): _say(ApprenticeDev.add_applicant())],
		["Hire one", func(): _say(ApprenticeDev.hire_one())],
		["Give materials for the queue", func(): _say(ApprenticeDev.give_materials())],
		["Advance to the next shift change", func(): _say(ApprenticeDev.advance_shift())],
		["Promote the first apprentice", func(): _say(ApprenticeDev.promote())],
		["Independence notice", func(): _say(ApprenticeDev.independence())],
		["Open the workshop ledger", func(): Events.open_panel.emit("workshop", {})]])
	_section("Representative progression states", [
		["New-game progression (keep the world)", func(): _preset("new")],
		["Mid-game: three workshops, skills 6", func(): _preset("mid")],
		["Late game: whole building, skills 14", func(): _preset("late")]])
	_section("Trade & Ironfront", [
		["Ship docks now", func(): _static_call("res://scripts/systems/trade.gd", "dev_force_ship", [""]); _say("A ship is in")],
		["Finish every import order", func(): _static_call("res://scripts/systems/trade.gd", "dev_finish_imports"); _say("Imports arrived")],
		["Grant 5 random Ironfront cards", func(): for i in 5: _grant_card(); _say("Cards granted")],
		["Open the harbour", func(): Events.open_panel.emit("harbour", {})],
		["Open the herbalist", func(): Events.open_panel.emit("herbalist", {})],
		["Open Ironfront", func(): Events.open_panel.emit("ironfront", {})]])


func _dev_epic() -> void:
	for a in Adv.all().values():
		var w: Dictionary = a.get("equipment", {}).get("weapon", {})
		if str(w.get("crafted_by", "")).begins_with("Brannoc"):
			var ok := Recognition.grant_epic(w, "a test deed in the developer tools", str(a["id"]))
			_say("Epic granted to %s's %s" % [a["name"], w.get("name", "")] if ok else "Could not grant Epic")
			return
	_say("No adventurer carries a smith-made weapon yet")


func _dev_awaken() -> void:
	for a in Adv.all().values():
		var w: Dictionary = a.get("equipment", {}).get("weapon", {})
		if Provenance.is_mine(w):
			ItemSpirit.awaken(w, "deed")
			_say("%s stirs (%s)" % [Items.display_name(w), ItemSpirit.type_name(str(ItemSpirit.spirit(w).get("type", "")))] if ItemSpirit.awake(w) else "It would not wake")
			Events.open_panel.emit("item", {"uid": int(w.get("uid", -1)), "tab": "Overview"})
			return
	_say("No adventurer carries a smith-made weapon yet")


func _grant_card() -> void:
	var c: Variant = _static_call("res://scripts/systems/ironfront.gd", "random_card", [""])
	if c != null:
		_static_call("res://scripts/systems/ironfront.gd", "grant_card", [str(c), "dev"])


func _set_level(skill: String, lvl: int) -> void:
	var sset: Dictionary = Game.state["player"]["skills"]
	if not sset.has(skill):
		sset[skill] = {"lvl": 0, "xp": 0}
	sset[skill]["lvl"] = clampi(lvl, 0, int(DB.skill_curve.get("max_level", 20)))
	sset[skill]["xp"] = 0
	Events.skill_level_up.emit("player", skill, int(sset[skill]["lvl"]))
	_say("%s set to %d" % [skill, int(sset[skill]["lvl"])])


func _buy_all_stations() -> void:
	Game.add_gold(20000, "dev", "Developer tools: funds for stations", "dev")
	var n := 0
	for sid in DB.stations:
		if not Property.is_owned_station(sid):
			(Property.st()["stored"] as Array).append(sid)
			n += 1
	_say("%d stations delivered to storage" % n)


func _secret_recipes() -> void:
	for r in DB.recipes.values():
		var f := str(r.get("requires_flag", ""))
		if f != "":
			Game.set_flag(f)
	Events.world_flag_changed.emit("recipes")
	_say("Secret recipes learned")


## Representative states for testing progression and the expanded building.
func _preset(kind: String) -> void:
	match kind:
		"new":
			Property.dev_reset_new()
			_static_call("res://scripts/systems/skilltree.gd", "reset_new")
			for sk in DB.skill_list:
				_set_level(str(sk["id"]), {"smithing": 4, "mining": 2, "alchemy": 1, "runecraft": 1, "travelling": 3, "relic_hunting": 2, "arcane_metalwork": 0, "enchanted_stitching": 1}.get(str(sk["id"]), 0))
		"mid":
			for uid in ["cobbler", "laundry", "weaver"]:
				Property.dev_grant_unit(uid)
			for sk in DB.skill_list:
				_set_level(str(sk["id"]), maxi(Game.player_level(str(sk["id"])), 6))
			Property.dev_install_in_owned()
			_static_call("res://scripts/systems/skilltree.gd", "unlock_available")
		"late":
			Property.dev_grant_all()
			for sk in DB.skill_list:
				_set_level(str(sk["id"]), maxi(Game.player_level(str(sk["id"])), 14))
			_static_call("res://scripts/systems/skilltree.gd", "unlock_all")
			if not Game.has_upgrade("arcane_foundry"):
				(Game.state["upgrades"] as Array).append("arcane_foundry")
	_rebuild("Progression preset: " + kind)


func _rebuild(msg: String) -> void:
	_say(msg)
	var main := get_tree().root.get_node_or_null("Main")
	if main and main.has_method("rebuild_world"):
		close()
		main.call_deferred("rebuild_world")


func _resolve_all() -> void:
	_step_all(400)
	for a in Adv.all().values():
		if a["status"] == "away" and not a.has("exp"):
			a["days_left"] = 1
	Adv.on_day()
	_say("Expeditions resolved")


func _depart_all() -> void:
	for a in Adv.in_town():
		a["depart_day"] = Game.day()
	_dispatch()


## The dawn routine on demand: parties form at the inn, buy supplies and march out.
func _dispatch() -> void:
	for a in Adv.all().values():
		Expeditions.ensure(a)
		if a["status"] == "in_town":
			a["hp"] = maxf(float(a["hp"]), float(a["hp_max"]) * 0.8)
			a["fatigue"] = minf(float(a["fatigue"]), 20.0)
	Expeditions.form_parties()
	Expeditions.prepare_parties()
	Expeditions.depart_parties()
	_say("%d expedition(s) on the road." % Expeditions.active().size())


## Steps each expedition `n` times, or until it is over (does not touch the clock).
func _step_all(n: int) -> void:
	var done := 0
	for eid in Expeditions.active().keys():
		var e: Dictionary = Expeditions.active()[eid]
		for i in n:
			if not Expeditions.active().has(eid):
				done += 1
				break
			Expeditions.step(e)
	Events.expeditions_changed.emit()
	_say("Stepped. %d finished, %d still out." % [done, Expeditions.active().size()])


func _hire_home() -> void:
	for h in Hire.list():
		if h["status"] == "away":
			h["expedition"]["days_left"] = 1
	Hire.on_day()
	_say("Hirelings home")


func _dispute() -> void:
	for a in Adv.in_town():
		if not a["equipment"].is_empty():
			Shop.raise_dispute(a["id"], a["equipment"].values()[0])
			_say("%s is coming to complain." % a["name"])
			return


func _rumours() -> void:
	for id in Adv.all():
		Game.set_flag("rumour_" + id)
	_say("Everyone's business is now yours")


func _aff(d: float) -> void:
	for a in Adv.in_town():
		Social.change(a["id"], d, 10.0)
	for v in ["aldric", "hilde", "martha", "tobin"]:
		Social.change(v, d, 10.0)
	_say("Affection shifted")
