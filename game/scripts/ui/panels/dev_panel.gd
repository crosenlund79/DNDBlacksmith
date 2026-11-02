## DevPanel — developer testing tools (F10). Not part of normal play: it never appears in menus and
## is only opened with its own key. Accelerates time, hands out representative materials and test
## items, and pokes the simulation so every system can be exercised quickly during playtesting.
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


func _init() -> void:
	super._init("Developer Tools — testing only (F10)", 1500, 860, true)


func _ready() -> void:
	super._ready()
	out = UIKit.rich("", 19, true)
	body = UIKit.vbox(8)
	_section("Time", [
		["+1 hour", func(): _adv(60)], ["+6 hours", func(): _adv(360)], ["+1 day", func(): _adv(1440)], ["+7 days", func(): _adv(1440 * 7)],
		["Skip to 7:00 (departures)", func(): Game.skip_to_hour(7); _say("Morning.")],
		["Skip to 19:00 (inn evening)", func(): Game.skip_to_hour(19); _say("Evening.")]])
	_section("Purse & skills", [
		["+1000 gold", func(): Game.add_gold(1000, "dev", "Developer funds"); _say("+1000 g")],
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
	_section("Relationships", [
		["+20 affection: everyone in town", func(): _aff(20.0)],
		["−20 affection: everyone in town", func(): _aff(-20.0)]])
	content.add_child(UIKit.scroll(body, 600))
	content.add_child(out)


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
		Game.add_item(Items.make(pair[0], {"qty": int(pair[1])}), false)
	Events.inventory_changed.emit()
	_say(k + " added")


func _item(def_id: String, q: float) -> void:
	Game.add_item(Items.make(def_id, {"quality": q, "crafted_by": "Brannoc Ironhand"}), false)
	Events.inventory_changed.emit()
	_say(DB.item(def_id)["name"] + " added")


func _legend() -> void:
	var it := Loot.random_equipment("legendary_demo")
	Game.add_item(it, false)
	Events.legendary_found.emit(it)
	_say("Legendary added")


func _potions() -> void:
	var p := Items.make("potion_healing", {"qty": 5, "quality": 90.0})
	p["for_sale"] = true
	Game.inventory().append(p)
	Events.inventory_changed.emit()
	_say("Draughts on the shelf")


func _resolve_all() -> void:
	for a in Adv.all().values():
		if a["status"] == "away":
			a["days_left"] = 1
	Adv.on_day()
	_say("Expeditions resolved")


func _depart_all() -> void:
	for a in Adv.in_town():
		a["depart_day"] = Game.day()
	Adv.morning_departures()
	_say("Departures")


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
