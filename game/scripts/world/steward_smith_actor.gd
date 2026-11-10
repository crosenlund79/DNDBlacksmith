## StewardSmithActor — the steward's working smith in the world (Milestone S2).
## EN: While Steward Mode runs, the smith's own figure is driven by the StewardSmith engine: when the engine sends him
##     somewhere (a station for the next operation, the grinding wheel for a repair, the hearth at the midday break, the
##     table in the quarters, his bed at night) this node walks him there with PlayerNav — the same walk grid, stairs and
##     lift as a click (Smithy.walk_to_station with use = false: he walks up and faces the station, nothing opens) — and
##     tells the engine when he has arrived; game time passes while he walks. At the station he works with the
##     apprentices' work motion (a hammer strike at the anvil, a slow tend at the forge or the trough), the world's own
##     sparks, smoke and flash after each finished operation and soft workshop sounds; a small bubble over his head says
##     what he is doing (and "asleep" at night). The camera stays on him (it is the player's camera). When the steward
##     stands down everything is let go. Headless (no world) the engine estimates the walks itself.
## DA: Smedens egen figur under forvalteren: går til stationerne, arbejder med lærlingenes bevægelse, holder pause,
##     sover i sin seng — en lille boble siger hvad han laver.
class_name StewardSmithActor
extends Node2D

const SYNC := 0.2
## A walk that ended this far from its goal (the path was blocked) puts him at the goal (rare; logged).
const FAR := 220.0

var w: VillageWorld
var _goal := ""
var _target := Vector2.ZERO
var _motion: Tween
var _motion_sid := ""
var _bubble: Node2D
var _bubble_label: Label
var _bubble_icon: TextureRect
var _bubble_text := ""
var _ops_seen := -1
var _t := 0.0
var _snd_t := 1.5


func _ready() -> void:
	name = "StewardSmithActor"
	w = get_parent() as VillageWorld
	StewardSmith.driver = self


func _exit_tree() -> void:
	if StewardSmith.driver == self:
		StewardSmith.driver = null
	_stop_motion()


func _process(delta: float) -> void:
	if Game.state.is_empty() or w == null or w.player == null:
		return
	if not Steward.is_active():
		if _goal != "" or _motion != null or _bubble != null or _ops_seen >= 0:
			_release()
		return
	_sounds(delta)
	_t -= delta
	if _t > 0.0:
		return
	_t = SYNC
	sync()


## Lets go of the figure (the steward stood down): no walk, no motion, no bubble.
func _release() -> void:
	var nav := PlayerNav.of(w)
	if nav != null and _goal != "":
		nav.cancel()
	_goal = ""
	_ops_seen = -1
	_stop_motion()
	if _bubble != null and is_instance_valid(_bubble):
		_bubble.queue_free()
	_bubble = null
	_bubble_text = ""


func sync() -> void:
	var nav := PlayerNav.of(w)
	var g := StewardSmith.goal()
	if g != "":
		if g != _goal:
			_goal = g
			_start_walk(g)
		elif nav == null or not nav.active():
			# the walk is over: there (or, when the way was blocked, set down at the goal)
			if _target != Vector2.ZERO and w.player.position.distance_to(_target) > FAR:
				Log.info("StewardSmithActor: the walk to %s ended %d px short — placed there." % [g, int(w.player.position.distance_to(_target))])
				_place_at(_target)
			StewardSmith.arrived(g)
			_goal = ""
	elif _goal != "" and nav != null and nav.active():
		nav.cancel()   # the engine changed its mind (e.g. the break began on the way)
		_goal = ""
	else:
		_goal = ""
	var s := StewardSmith.status()
	var m := StewardSmith.sm()
	var place := str(m.get("place", ""))
	var walking := bool(m.get("walking", false))
	var sid := ""
	if str(s.get("act", "")) == "work" and not walking and place.begins_with("station:"):
		sid = place.trim_prefix("station:")
	if sid != "":
		_face(w.station_pos(sid))
		_start_motion(sid)
	else:
		_stop_motion()
	# an operation (or a repair) was finished: the station answers as it does for the smith's own checks
	var ops := int(m.get("ops_n", 0))
	if _ops_seen >= 0 and ops > _ops_seen and place.begins_with("station:"):
		var st := place.trim_prefix("station:")
		if w.has_method("_station_worked"):
			w.call("_station_worked", st, 90.0)
	_ops_seen = ops
	_show_bubble(str(s.get("activity", "")), _icon_for(str(s.get("act", ""))))


# ======================================================================= walking
func _start_walk(place: String) -> void:
	var nav := PlayerNav.of(w)
	_target = Vector2.ZERO
	if nav == null:
		StewardSmith.arrived(place)
		return
	var ok := false
	if place.begins_with("station:"):
		var sid := place.trim_prefix("station:")
		_target = w.station_pos(sid)
		ok = Smithy.walk_to_station(sid, w, false) == ""
	else:
		var e := _home_entity(place)
		if not e.is_empty():
			_target = e["pos"]
			ok = nav.walk_to_entity(e, false)
		elif place == "table" and w.spots.has("quarters_table"):
			_target = (w.spots["quarters_table"] as Vector2) + Vector2(0, 70)
			ok = nav.walk_to_point(_target)
	if not ok:
		# no way there from here (or nothing to walk to): he is put at the place, so the work can go on
		if _target != Vector2.ZERO:
			_place_at(_target)
		StewardSmith.arrived(place)
		_goal = ""


## The bed, the hearth (armchair) or the table's interactable for a place of his day.
func _home_entity(place: String) -> Dictionary:
	var want: Array = {"bed": ["player_bed", "cot"], "armchair": ["armchair"], "table": []}.get(place, [])
	for id in want:
		for e in w.interactables:
			if str(e.get("kind", "")) == "bed" and str(e.get("id", "")) == str(id):
				return e
	if place == "table":
		return {}
	for e2 in w.interactables:
		if str(e2.get("kind", "")) == "bed":
			return e2
	return {}


func _place_at(p: Vector2) -> void:
	var nav := PlayerNav.of(w)
	var at := p + Vector2(0, 60)
	if nav != null:
		nav.cancel()
		var c := nav.nearest_cell(at, 200.0)
		if c.x != -99999:
			at = Vector2(c) * PlayerNav.CELL
	w.player.position = at
	w.camera.reset_smoothing()


func _face(p: Vector2) -> void:
	var d := p - w.player.position
	if d.length() > 1.0:
		w.player.facing = ("e" if d.x > 0 else "w") if absf(d.x) > absf(d.y) else ("s" if d.y > 0 else "n")


# ======================================================================= the work motion (as the apprentices')
func _start_motion(sid: String) -> void:
	if _motion != null and _motion.is_valid() and _motion.is_running() and _motion_sid == sid:
		return
	_stop_motion()
	var s := w.player.sprite
	var tw := s.create_tween().set_loops()
	if ApprenticeActors.STRIKE.has(sid):
		tw.tween_property(s, "offset:y", -38.0, 0.18).set_trans(Tween.TRANS_SINE)
		tw.tween_property(s, "offset:y", -30.0, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(s, "offset:y", -32.0, 0.12)
		tw.tween_interval(0.32)
	else:
		tw.tween_property(s, "rotation", 0.07, 0.55).set_trans(Tween.TRANS_SINE)
		tw.tween_property(s, "rotation", -0.07, 0.55).set_trans(Tween.TRANS_SINE)
	_motion = tw
	_motion_sid = sid


func _stop_motion() -> void:
	if _motion != null and _motion.is_valid():
		_motion.kill()
	_motion = null
	_motion_sid = ""
	if w != null and w.player != null and w.player.sprite != null:
		w.player.sprite.offset = Vector2(0, -32)
		w.player.sprite.rotation = 0.0


## Is he at work at a station right now (the motion runs)? For tests and the playtest.
func working() -> bool:
	return _motion != null and _motion.is_valid() and _motion_sid != ""


func _sounds(delta: float) -> void:
	_snd_t -= delta
	if _snd_t > 0.0 or _motion_sid == "" or Game.ui_blockers > 0:
		return
	_snd_t = randf_range(2.2, 3.8)
	var arr: Array = ApprenticeActors.SOUNDS.get(_motion_sid, [])
	if not arr.is_empty():
		Audio.play(str(arr.pick_random()), -14.0, randf_range(0.94, 1.04))


# ======================================================================= the bubble over his head
func _icon_for(act: String) -> String:
	match act:
		"sleep":
			return "ui/act_zzz"
		"break", "home", "rest":
			return "icons/bread_cheese"
		"walk":
			return "ui/act_road"
	return "ui/act_hammer"


func _show_bubble(text: String, icon: String) -> void:
	if text == "":
		return
	if _bubble == null or not is_instance_valid(_bubble):
		_bubble = _make_bubble()
		w.player.add_child(_bubble)
		_bubble_text = ""
	if text == _bubble_text:
		return
	_bubble_text = text
	_bubble_label.text = StewardUI.clip(text, 70)
	if Assets.has_tex(icon):
		_bubble_icon.texture = Assets.get_tex(icon)
	var panel := _bubble.get_child(0) as PanelContainer
	panel.reset_size()
	var sz := panel.get_combined_minimum_size()
	panel.position = Vector2(-sz.x * 0.5, -sz.y)


## The same inked bubble as the village's activity bubbles (ActivityBubbles), but it stays while he works.
func _make_bubble() -> Node2D:
	var node := Node2D.new()
	node.name = "StewardSmithBubble"
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
	_bubble_icon = TextureRect.new()
	_bubble_icon.custom_minimum_size = Vector2(24, 24)
	_bubble_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bubble_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_bubble_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_bubble_icon)
	_bubble_label = Label.new()
	_bubble_label.add_theme_font_override("font", Assets.font("body_italic"))
	_bubble_label.add_theme_font_size_override("font_size", 17)
	_bubble_label.add_theme_color_override("font_color", Color("#20140c"))
	_bubble_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_bubble_label)
	panel.add_child(row)
	node.add_child(panel)
	var tail := Polygon2D.new()
	tail.polygon = PackedVector2Array([Vector2(-7, 0), Vector2(7, 0), Vector2(0, 11)])
	tail.color = Color("#f1e4c2")
	tail.position = Vector2(0, -1)
	node.add_child(tail)
	var tl := Line2D.new()
	tl.points = PackedVector2Array([Vector2(-7, 1), Vector2(0, 11), Vector2(7, 1)])
	tl.width = 2.0
	tl.default_color = Color("#20140c")
	tl.position = Vector2(0, -1)
	node.add_child(tl)
	return node


## The bubble's text (tests and the playtest).
func bubble_text() -> String:
	return _bubble_text if _bubble != null and is_instance_valid(_bubble) else ""
