## SpiritVoice — shows what an awakened piece says (ItemSpirit) as a small ink-violet speech bubble, the item's
## icon and name as the speaker. Same inked bubble as the villagers' ActivityBubbles, tinted violet so it reads as
## the voice of a thing, not a person.
## EN: The bubble sits where the smith is working: over the skill check while one is open (the check overlay),
##     over the open work panel (station, stores, record of the work), or above the station in the forge
##     (grinding wheel, rune stand, infusion rack, anvil) — else above the smith. Now and then an awakened piece on
##     display in the forge mutters to itself ("idle"), when nothing else is happening. Added by UIRoot.
## DA: Viser hvad en vågnet genstand siger som en lille violet taleboble med genstandens navn.
class_name SpiritVoice
extends CanvasLayer

const BG := Color("#ebe0f2")
const BORDER := Color("#3d2257")
const NAME_COL := Color("#5b3a7e")
const TEXT_COL := Color("#2a1840")
const MAX_TEXT_W := 470.0
const IDLE_EVERY := Vector2(28.0, 46.0)     # real seconds between idle murmurs (cooldowns still apply)
const STATION_FOR := {"repair": "grinding_wheel", "sharpen": "grinding_wheel", "enchant": "rune_engraving_stand",
	"treat": "infusion_rack", "reforge": "anvil"}

static var instance: SpiritVoice

var _seen := 0
var _bubble: Control
var _tail: Node2D
var _ctx := ""
var _idle_t := 20.0


func _ready() -> void:
	instance = self
	layer = 12
	name = "SpiritVoice"
	ItemSpirit.wire()
	_seen = ItemSpirit.serial


func _process(delta: float) -> void:
	if ItemSpirit.serial != _seen:
		_seen = ItemSpirit.serial
		show_line(ItemSpirit.last)
	if is_instance_valid(_bubble):
		_place()
	_idle_t -= delta
	if _idle_t <= 0.0:
		_idle_t = randf_range(IDLE_EVERY.x, IDLE_EVERY.y)
		_idle()


## An awakened piece on display mutters when the smith is in the forge and nothing is open.
func _idle() -> void:
	if Game.state.is_empty() or not ItemSpirit.voices_on():
		return
	var w := _world()
	if w == null or w.area != "smithy" or _check_host() != null or _panel() != null:
		return
	for it in Game.inventory():
		if bool(it.get("for_sale", false)) and ItemSpirit.awake(it):
			if ItemSpirit.speak(it, "idle") != "":
				return


func _world() -> VillageWorld:
	return get_tree().get_first_node_in_group("world") as VillageWorld


func _check_host() -> Control:
	if UIRoot.instance == null:
		return null
	for c in UIRoot.instance.panel_host.get_children():
		if (c is SkillCheckPanel or c is MinigameBase) and not c.is_queued_for_deletion():
			return c
	return null


func _panel() -> Control:
	if UIRoot.instance == null:
		return null
	var p: Control = UIRoot.instance.current
	if is_instance_valid(p) and p.visible and not p.is_queued_for_deletion():
		return p
	return null


func show_line(l: Dictionary) -> void:
	if l.is_empty():
		return
	if is_instance_valid(_bubble):
		_bubble.queue_free()
	_ctx = str(l.get("context", ""))
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG
	sb.border_color = BORDER
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 10
	sb.content_margin_right = 14
	sb.content_margin_top = 5
	sb.content_margin_bottom = 7
	sb.shadow_color = Color(0.12, 0.04, 0.2, 0.3)
	sb.shadow_size = 4
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := TextureRect.new()
	ic.texture = Assets.get_tex(str(l.get("icon", "icons/rune")))
	ic.custom_minimum_size = Vector2(40, 40)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(ic)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var who := Label.new()
	who.text = str(l.get("name", ""))
	who.add_theme_font_override("font", Assets.font("title"))
	who.add_theme_font_size_override("font_size", 16)
	who.add_theme_color_override("font_color", NAME_COL)
	who.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(who)
	var lab := Label.new()
	var txt := "“%s”" % str(l.get("text", ""))
	lab.text = txt
	var f := Assets.font("body_italic")
	lab.add_theme_font_override("font", f)
	lab.add_theme_font_size_override("font_size", 19)
	lab.add_theme_color_override("font_color", TEXT_COL)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
	if w > MAX_TEXT_W:
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lab.custom_minimum_size = Vector2(MAX_TEXT_W, 0)
	col.add_child(lab)
	row.add_child(col)
	panel.add_child(row)
	root.add_child(panel)
	# the little tail pointing at the work
	var tail := Node2D.new()
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([Vector2(-9, -2), Vector2(9, -2), Vector2(0, 13)])
	poly.color = BG
	tail.add_child(poly)
	var tl := Line2D.new()
	tl.points = PackedVector2Array([Vector2(-9, 0), Vector2(0, 13), Vector2(9, 0)])
	tl.width = 2.0
	tl.default_color = BORDER
	tail.add_child(tl)
	root.add_child(tail)
	add_child(root)
	panel.reset_size()
	var sz := panel.get_combined_minimum_size()
	panel.size = sz
	panel.position = Vector2(-sz.x * 0.5, -sz.y - 12)
	tail.position = Vector2(0, -13)
	_bubble = root
	_tail = tail
	_place()
	root.modulate.a = 0.0
	var secs := clampf(3.4 + txt.length() * 0.05, 4.0, 7.5)
	var tw := root.create_tween()
	tw.tween_property(root, "modulate:a", 1.0, 0.4)
	tw.tween_interval(secs)
	tw.tween_property(root, "modulate:a", 0.0, 0.8)
	tw.tween_callback(func():
		if _bubble == root:
			_bubble = null
		root.queue_free())


## Where the bubble's tail points: the check, the open panel, the station in the forge, or the smith.
func anchor() -> Vector2:
	var vp := get_viewport().get_visible_rect().size
	if _check_host() != null:
		return Vector2(vp.x * 0.5 - 250.0, vp.y * 0.5 - 330.0)
	var p := _panel()
	if p != null:
		var r := p.get_global_rect()
		return Vector2(r.position.x + r.size.x * 0.5, maxf(r.position.y + 6.0, 120.0))
	var w := _world()
	if w != null and w.player != null:
		var pos: Vector2 = w.player.position + Vector2(0, -120)
		var st := str(STATION_FOR.get(_ctx, ""))
		if st != "" and w.area == "smithy" and Property.is_installed(st):
			pos = w.station_pos(st) + Vector2(0, -70)
		return w.get_viewport().get_canvas_transform() * pos
	return Vector2(vp.x * 0.5, vp.y * 0.4)


func _place() -> void:
	if not is_instance_valid(_bubble):
		return
	var a := anchor()
	var vp := get_viewport().get_visible_rect().size
	var pc: Control = _bubble.get_child(0)
	var half := pc.size.x * 0.5
	# keep the bubble on screen; the tail stays on the anchor
	var x := clampf(a.x, half + 16.0, vp.x - half - 16.0)
	var y := clampf(a.y, pc.size.y + 30.0, vp.y - 10.0)
	_bubble.position = Vector2(x, y)
	_tail.position = Vector2(clampf(a.x - x, -half + 18.0, half - 18.0), -13)


## Is a bubble showing (tests and the play-test)?
func showing() -> bool:
	return is_instance_valid(_bubble)
