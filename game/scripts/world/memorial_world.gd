## MemorialWorld — remembrance in the village: headstones of fallen hirelings in the graveyard, the funeral
## gathering and its short scene, the friendly ghost in the workshop on a quiet evening, wildflowers on
## the smithy step, and the vase in the quarters that keeps them.
## EN: State lives in Memorial (Game.state["memorial"]); this node only shows it and handles the
##     interactables it adds (grave, remembrance_flowers, ghost) plus the lead-placed vase/quarters.
## DA: Viser gravsten, begravelsen, genfærdet, blomsterne ved døren og vasen; tilstanden ligger i Memorial.
class_name MemorialWorld
extends Node2D

const T := 64.0
## Plots used when the village layout has no graveyard_1..8 spots: two rows inside the graveyard wall.
const FALLBACK_PLOTS := [[67.6, 59.5], [69.2, 59.5], [70.8, 59.5], [72.4, 59.5], [67.6, 61.7], [69.2, 61.7], [70.8, 61.7], [72.2, 61.9]]
const SCENE_RADIUS := 560.0
const MOURNER_OFFSETS := [Vector2(-175, 40), Vector2(160, 40), Vector2(-215, 125), Vector2(205, 125), Vector2(-120, 165),
	Vector2(120, 165), Vector2(-280, 75), Vector2(270, 75), Vector2(0, 230)]

var w: VillageWorld
var _graves := {}            # grave id -> {node, entry}
var _flower_nodes: Array = []
var _flower_entries: Array = []
var _vase_sprite: Sprite2D
var _vase_entry: Dictionary = {}
var _ghost: Node2D
var _ghost_sprite: AnimatedSprite2D
var _ghost_bubble: Label
var _ghost_entry: Dictionary = {}
var _ghost_id := ""
var _ghost_t := 0.0
var _ghost_leaving := false
var _poll := 0.0
var _scene_running := false


func _ready() -> void:
	name = "MemorialWorld"
	w = get_parent() as VillageWorld
	_register_funeral_spots()
	_find_vase()
	refresh()
	Events.hour_passed.connect(func(_d, _h): refresh())
	Events.day_started.connect(func(_d): refresh())
	Events.hirelings_changed.connect(refresh)
	Events.inventory_changed.connect(_refresh_vase)


## World position of grave plot `i` (0-based).
func plot_pos(i: int) -> Vector2:
	var sid := "graveyard_%d" % (i + 1)
	if w.spots.has(sid):
		return w.spots[sid]
	var p: Array = FALLBACK_PLOTS[i % FALLBACK_PLOTS.size()]
	return Vector2(float(p[0]) * T, float(p[1]) * T)


## Mourner spots around every plot, joined to the graveyard gate on the walking graph.
func _register_funeral_spots() -> void:
	var gate := -1
	if w.spot_ids.has("graveyard"):
		gate = int(w.spot_ids["graveyard"])
	for plot in Memorial.PLOTS:
		var g := plot_pos(plot)
		var pts := {"funeral_%d_priest" % plot: g + Vector2(-80, 70)}
		# mourners stand to either side and behind, leaving the stone in plain view
		for k in MOURNER_OFFSETS.size():
			pts["funeral_%d_%d" % [plot, k]] = g + MOURNER_OFFSETS[k]
		for sid: String in pts:
			w.spots[sid] = pts[sid]
			var pid := w._pt(pts[sid])
			w.spot_ids[sid] = pid
			if gate >= 0:
				w.astar.connect_points(pid, gate)
			else:
				w._link_nearest(pid, 1400.0, 2)


func refresh() -> void:
	if Game.state.is_empty():
		return
	_refresh_graves()
	_refresh_flowers()
	_refresh_vase()


# ======================================================================= graves
func _refresh_graves() -> void:
	var want := {}
	for g in Memorial.standing():
		want[str(g["id"])] = g
	for gid: String in _graves.keys():
		if not want.has(gid):
			(_graves[gid]["node"] as Node).queue_free()
			w.interactables.erase(_graves[gid]["entry"])
			_graves.erase(gid)
	for gid: String in want:
		if _graves.has(gid):
			continue
		var g: Dictionary = want[gid]
		var pos := plot_pos(int(g["plot"]))
		var holder := Node2D.new()
		holder.position = pos + Vector2(0, 24)
		var s := Sprite2D.new()
		s.texture = Assets.get_tex("props/headstone_hireling", Vector2i(64, 80))
		s.position = Vector2(0, -24)
		holder.add_child(s)
		var lab := Label.new()
		lab.text = str(g["name"]).get_slice(" ", 0)
		lab.add_theme_font_override("font", Assets.font("heading"))
		lab.add_theme_font_size_override("font_size", 11)
		lab.add_theme_color_override("font_color", Color(0.18, 0.13, 0.09, 0.9))
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.position = Vector2(-22, -48)
		lab.size = Vector2(44, 14)
		lab.clip_text = true
		holder.add_child(lab)
		var lab2 := Label.new()
		lab2.text = "d. %d" % int(g["died_day"])
		lab2.add_theme_font_override("font", Assets.font("body_italic"))
		lab2.add_theme_font_size_override("font_size", 9)
		lab2.add_theme_color_override("font_color", Color(0.18, 0.13, 0.09, 0.8))
		lab2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab2.position = Vector2(-22, -36)
		lab2.size = Vector2(44, 12)
		holder.add_child(lab2)
		w.ysort.add_child(holder)
		var e := w._add_interactable(pos + Vector2(0, 30), 100.0, "grave", gid, "Headstone — %s" % g["name"])
		_graves[gid] = {"node": holder, "entry": e}


func grave_pos(gid: String) -> Vector2:
	var g := Memorial.grave(gid)
	return plot_pos(int(g.get("plot", 0)))


# ======================================================================= flowers on the step
func flowers_spot() -> Vector2:
	return w.spots.get("smithy_door_out", Vector2.ZERO) + Vector2(52, 2)


func _refresh_flowers() -> void:
	for n in _flower_nodes:
		(n as Node).queue_free()
	for e in _flower_entries:
		w.interactables.erase(e)
	_flower_nodes.clear()
	_flower_entries.clear()
	var fl := Memorial.flowers_at_door()
	for i in fl.size():
		var s := Sprite2D.new()
		s.texture = Assets.get_tex("props/wildflowers_bundle", Vector2i(48, 40))
		s.position = flowers_spot() + Vector2(i * 22, i * 6)
		s.rotation = -0.2 + i * 0.35
		s.scale = Vector2(1.25, 1.25)
		w.floor_layer.add_child(s)
		_flower_nodes.append(s)
	if not fl.is_empty():
		_flower_entries.append(w._add_interactable(flowers_spot(), 90.0, "remembrance_flowers", "door", "Wildflowers on the step — pick them up"))


# ======================================================================= the vase
func _find_vase() -> void:
	var tex := Assets.get_tex("props/vase", Vector2i(48, 64))
	for holder in w.ysort.get_children():
		for c in holder.get_children():
			if c is Sprite2D and (c as Sprite2D).texture == tex:
				_vase_sprite = c
	for e in w.interactables:
		if str(e.get("kind", "")) == "vase":
			_vase_entry = e


func _refresh_vase() -> void:
	if Game.state.is_empty():
		return
	var v := Memorial.vase()
	if is_instance_valid(_vase_sprite):
		_vase_sprite.texture = Assets.get_tex("props/vase_flowers" if not v.is_empty() else "props/vase", Vector2i(48, 64))
	if not _vase_entry.is_empty():
		if not Memorial.flowers_in_pack().is_empty():
			_vase_entry["label"] = "The vase — put the wildflowers in it"
		elif not v.is_empty():
			_vase_entry["label"] = "The vase — wildflowers%s" % ((" from " + str(v["name"])) if str(v.get("name", "")) != "" else "")
		else:
			_vase_entry["label"] = "The vase"
		if w._focus == _vase_entry:
			Events.open_panel.emit("prompt", {"text": _vase_entry["label"]})


func has_flowers_in_vase() -> bool:
	return is_instance_valid(_vase_sprite) and _vase_sprite.texture == Assets.get_tex("props/vase_flowers", Vector2i(48, 64))


# ======================================================================= interaction (VillageWorld.interact hook)
func interact(e: Dictionary) -> void:
	match str(e["kind"]):
		"grave":
			var g := Memorial.grave(str(e["id"]))
			if not g.is_empty():
				UIRoot.instance.open(MemorialPanel.new("grave", "Here lies %s" % g["name"], Memorial.epitaph(g), "portraits/" + str(g["look"])))
		"remembrance_flowers":
			if not Memorial.collect_flowers().is_empty():
				Audio.play("sfx/page_turn", -8.0)
			_refresh_flowers()
			_refresh_vase()
		"ghost":
			var g2 := Memorial.grave(_ghost_id)
			var line := Memorial.meet_ghost()
			if line != "":
				UIRoot.instance.open(MemorialPanel.new("ghost", "%s" % g2.get("name", ""),
					"[i]The figure at the forge is pale and not quite there, but it is unmistakably %s. They smile.[/i]\n\n%s" % [g2.get("name", ""), line],
					"portraits/" + str(g2.get("look", ""))))
				_ghost_bubble.text = "\"Goodnight, smith.\""
				_ghost_bubble.visible = true
				_ghost_leaving = true
				_ghost_t = 0.0
		"vase":
			if Memorial.place_in_vase():
				Audio.play("sfx/page_turn", -8.0)
				_refresh_vase()
				Events.toast.emit("You set the wildflowers in the vase. The little room smells of the meadow.", "good")
			else:
				UIRoot.instance.open(MemorialPanel.new("vase", "The vase", Memorial.vase_text()))


# ======================================================================= frame: ghost and funeral
func _process(delta: float) -> void:
	if Game.state.is_empty() or w.player == null:
		return
	_poll += delta
	if _poll >= 0.5:
		_poll = 0.0
		_check_ghost()
		_check_funeral()
	if is_instance_valid(_ghost):
		_ghost_t += delta
		_ghost_sprite.position.y = -6.0 + sin(_ghost_t * 1.6) * 5.0
		_ghost_entry["pos"] = _ghost.position
		var to_p := w.player.position - _ghost.position
		if to_p.length() < 320.0:
			_ghost_sprite.play("idle_" + ("e" if to_p.x > 0 else "w") if absf(to_p.x) > absf(to_p.y) else ("idle_s" if to_p.y > 0 else "idle_n"))
		if _ghost_leaving:
			_ghost.modulate.a = maxf(0.0, 1.0 - _ghost_t / 5.0)
			if _ghost_t > 5.0 and Game.ui_blockers == 0:
				_remove_ghost()


func _check_ghost() -> void:
	var g := Memorial.ghost_now()
	if g.is_empty():
		if is_instance_valid(_ghost) and not _ghost_leaving:
			_ghost_leaving = true
			_ghost_t = 0.0
		return
	if is_instance_valid(_ghost):
		return
	_spawn_ghost(g)


func ghost_spot() -> Vector2:
	for sid in ["work_smithing", "work_mining", "smithy_inside"]:
		if w.spots.has(sid):
			return w.spots[sid] + Vector2(110, 50)
	return w.player.position


func _spawn_ghost(g: Dictionary) -> void:
	_ghost_id = str(g["id"])
	_ghost_leaving = false
	_ghost_t = 0.0
	_ghost = Node2D.new()
	_ghost.position = ghost_spot()
	_ghost_sprite = AnimatedSprite2D.new()
	_ghost_sprite.sprite_frames = Assets.char_frames("chars/" + str(g["look"]))
	_ghost_sprite.offset = Vector2(0, -32)
	_ghost_sprite.scale = Vector2(1.15, 1.15)
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/ghost.gdshader")
	_ghost_sprite.material = m
	_ghost_sprite.play("idle_s")
	_ghost.add_child(_ghost_sprite)
	var l := FX.light(Color("#a8c8ff"), 200.0, 0.55, true)
	l.position = Vector2(0, -30)
	_ghost.add_child(l)
	_ghost_bubble = Label.new()
	_ghost_bubble.add_theme_font_override("font", Assets.font("body_italic"))
	_ghost_bubble.add_theme_font_size_override("font_size", 17)
	_ghost_bubble.add_theme_color_override("font_color", Color("#e8f0ff"))
	_ghost_bubble.add_theme_color_override("font_outline_color", Color("#1a2230"))
	_ghost_bubble.add_theme_constant_override("outline_size", 6)
	_ghost_bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ghost_bubble.position = Vector2(-120, -130)
	_ghost_bubble.size = Vector2(240, 24)
	_ghost_bubble.text = "%s…?" % str(g["name"]).get_slice(" ", 0)
	_ghost.add_child(_ghost_bubble)
	w.ysort.add_child(_ghost)
	_ghost_entry = w._add_interactable(_ghost.position, 110.0, "ghost", _ghost_id, "Speak with %s" % g["name"])


func _remove_ghost() -> void:
	if is_instance_valid(_ghost):
		_ghost.queue_free()
	w.interactables.erase(_ghost_entry)
	_ghost_entry = {}
	_ghost = null
	_ghost_leaving = false


func ghost_visible() -> bool:
	return is_instance_valid(_ghost) and not _ghost_leaving


# ======================================================================= the funeral scene
func _check_funeral() -> void:
	if _scene_running or not Memorial.funeral_now():
		return
	var g := Memorial.funeral_today()
	if w.player.position.distance_to(plot_pos(int(g["plot"]))) > SCENE_RADIUS:
		return
	_scene_running = true
	_funeral_scene(g)


func _funeral_scene(g: Dictionary) -> void:
	var name_s := str(g["name"])
	var oswin: NPCActor = w.npcs.get("oswin")
	if oswin and oswin.visible:
		oswin.say("\"We are gathered to lay %s to rest.\"" % name_s, 4.5)
	await get_tree().create_timer(4.8).timeout
	# one voice from the gathering, then quiet
	for id: String in Memorial.mourners():
		var n: NPCActor = w.npcs.get(id)
		if n and n.visible and id != "oswin":
			n.say(["\"Good hands, they had.\"", "\"Rest well, friend.\""][absi(name_s.hash()) % 2], 3.5)
			break
	await get_tree().create_timer(3.5).timeout
	if oswin and oswin.visible:
		oswin.say("\"The forge will remember the hands that fed it.\"", 4.0)
	await get_tree().create_timer(3.5).timeout
	Memorial.attend()
	Events.request_fade.emit("Father Oswin speaks of %s. The village stands with you in the cold morning." % name_s, 40)
	Events.toast.emit("You attended %s's funeral." % name_s, "info")
	refresh()
	_scene_running = false
