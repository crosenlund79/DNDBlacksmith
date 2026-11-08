## ActivityBubbles — small inked bubbles above people near the smith saying what they are about
## ("sorting ore", "brewing", "zzz", "heading to Ironroot Mine"). Hirelings first, a few at a time,
## fading in and out every so often. Icons are drawn art (the project fonts have no emoji).
## DA: Små tegnede talebobler over folk tæt på smeden: hvad de laver lige nu. Ansatte først.
class_name ActivityBubbles
extends Node2D

const MAX_SHOWN := 3
const NEAR := 760.0
const SHOW_SECONDS := 4.2

var w: VillageWorld
var _t := 1.5
var _live := {}          # npc id -> bubble node


func _ready() -> void:
	name = "ActivityBubbles"
	w = get_parent() as VillageWorld
	Events.hour_passed.connect(func(_d, _h): clear())


## Fades out every bubble (the hour turned; what people do has changed).
func clear() -> void:
	for id: String in _live:
		if is_instance_valid(_live[id]):
			(_live[id] as Node).queue_free()
	_live.clear()


func _process(delta: float) -> void:
	if Game.state.is_empty() or w == null or w.player == null:
		return
	_t -= delta
	if _t > 0.0:
		return
	_t = randf_range(2.6, 4.4)
	for id: String in _live.keys():
		if not is_instance_valid(_live[id]):
			_live.erase(id)
	if _live.size() >= MAX_SHOWN:
		return
	# nearby, visible, not already speaking; hirelings first
	var cands := []
	for id: String in w.npcs:
		var n: NPCActor = w.npcs[id]
		if not n.visible or _live.has(id) or n.bubble.visible or _crowded(n):
			continue
		var d := n.position.distance_to(w.player.position)
		if d > NEAR:
			continue
		var b := text_for(id, n)
		if b.is_empty():
			continue
		var staff: bool = not Hire.get_h(id).is_empty() or bool(n.get_meta("apprentice", false))
		var pri := d - (600.0 if staff else 0.0) + randf() * 200.0
		cands.append([pri, id, b])
	cands.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	if not cands.is_empty():
		var c: Array = cands[0]
		show_bubble(str(c[1]), c[2])


## Another bubble already floats right next to this person.
func _crowded(n: NPCActor) -> bool:
	for id: String in _live:
		var o: NPCActor = w.npcs.get(id)
		if o and o.position.distance_to(n.position) < 140.0:
			return true
	return false


## {icon, text} for what this person is doing, or {} when there is nothing worth saying.
func text_for(id: String, n: NPCActor) -> Dictionary:
	var hr := Game.hour()
	if n.get_meta("apprentice", false):
		# iteration 012: a workshop apprentice says what they are doing (only once they stand still at it)
		var a := Apprentices.get_a(id)
		if a.is_empty() or n.path.size() > 0:
			return {}
		return ApprenticeUI.bubble(a)
	if n.target_spot.begins_with("funeral_"):
		return {} if Memorial.funeral_now() else {"icon": "ui/act_candle", "text": "…"}
	if n.get_meta("travelling", false) and n.get_meta("leaving", false):
		var dest := ""
		var h0 := Hire.get_h(id)
		if not h0.is_empty():
			dest = str(DB.destinations.get(str(h0.get("expedition", {}).get("dest", "")), {}).get("name", ""))
		return {"icon": "ui/act_road", "text": ("heading to " + dest) if dest != "" else "off on the road"}
	var h := Hire.get_h(id)
	if not h.is_empty():
		match str(h["status"]):
			"injured":
				return {"icon": "ui/act_bandage", "text": "zzz" if hr >= 21 else "nursing a sore arm"}
			"working":
				if not Game.is_work_hours():
					return {"icon": "ui/act_zzz", "text": "zzz"} if hr >= 22 else {"icon": "icons/ale_mug", "text": "a pint after work"}
				var act := str(Hire.hud_info(h)["activity"])
				var words := {"mining": "sorting ore", "smithing": "at the anvil", "alchemy": "brewing", "runecraft": "splitting runestones",
					"travelling": "counting coin for the road", "relic_hunting": "sifting for relics"}
				return {"icon": str(Hire.ACT_ICONS.get(act, "ui/act_hammer")), "text": str(words.get(act, "at work"))}
		return {}
	var spot := n.target_spot
	if n.path.size() > 0:
		return {}
	if hr >= 22 or hr < 6:
		return {"icon": "ui/act_zzz", "text": "zzz"} if randf() < 0.5 else {}
	if spot == "well":
		return {"icon": "icons/potion_healing", "text": "drawing water"}
	if spot.begins_with("pond_"):
		return {"icon": "icons/bread_cheese", "text": "feeding the ducks"}
	if spot == "fields":
		return {"icon": "icons/herb_emberleaf", "text": "tending the rows"}
	if spot in ["inn_bar", "inn_hearth"] or spot.begins_with("inn_t"):
		return {"icon": "icons/ale_mug", "text": ["another round", "a warm seat", "tall tales"][absi(id.hash()) % 3]}
	if spot == "herbalist_counter":
		return {"icon": "icons/herb_moonwort", "text": "sorting herbs"}
	if spot == "grocery_behind":
		return {"icon": "icons/bread_cheese", "text": "stacking crates"}
	if spot == "harbour_quay":
		return {"icon": "ui/act_road", "text": "watching the tide"}
	if spot == "notice":
		return {"icon": "icons/recipe_scroll", "text": "reading the notices"}
	return {}


func show_bubble(id: String, b: Dictionary) -> void:
	var n: NPCActor = w.npcs.get(id)
	if n == null:
		return
	var node := Node2D.new()
	node.z_index = 30
	node.position = Vector2(0, -150)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#f1e4c2")
	sb.border_color = Color("#20140c")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 8
	sb.content_margin_right = 10
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	sb.shadow_color = Color(0, 0, 0, 0.25)
	sb.shadow_size = 3
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := TextureRect.new()
	ic.texture = Assets.get_tex(str(b["icon"]))
	ic.custom_minimum_size = Vector2(24, 24)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(ic)
	var lab := Label.new()
	lab.text = str(b["text"])
	lab.add_theme_font_override("font", Assets.font("body_italic"))
	lab.add_theme_font_size_override("font_size", 17)
	lab.add_theme_color_override("font_color", Color("#20140c"))
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lab)
	panel.add_child(row)
	node.add_child(panel)
	# the little tail pointing down at the speaker
	var tail := Polygon2D.new()
	tail.polygon = PackedVector2Array([Vector2(-7, 0), Vector2(7, 0), Vector2(0, 11)])
	tail.color = Color("#f1e4c2")
	node.add_child(tail)
	var tl := Line2D.new()
	tl.points = PackedVector2Array([Vector2(-7, 1), Vector2(0, 11), Vector2(7, 1)])
	tl.width = 2.0
	tl.default_color = Color("#20140c")
	node.add_child(tl)
	n.add_child(node)
	# centre over the head once the panel knows its size
	panel.reset_size()
	var sz := panel.get_combined_minimum_size()
	panel.position = Vector2(-sz.x * 0.5, -sz.y)
	tail.position = Vector2(0, -1)
	tl.position = Vector2(0, -1)
	_live[id] = node
	node.modulate.a = 0.0
	var tw := node.create_tween()
	tw.tween_property(node, "modulate:a", 1.0, 0.35)
	tw.tween_interval(SHOW_SECONDS)
	tw.tween_property(node, "modulate:a", 0.0, 0.6)
	tw.tween_callback(func():
		_live.erase(id)
		node.queue_free())


## How many bubbles are showing (tests and the playtest).
func shown() -> int:
	return _live.size()
